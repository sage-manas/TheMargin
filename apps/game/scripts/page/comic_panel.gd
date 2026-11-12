class_name ComicPanel
extends Node2D
## One comic panel: a room bounded by an ink border (GDD §4.1).
## Node position = panel top-left in page coordinates. Children:
##   BorderBody / SolidBody (physics, never shaken)
##   Shadow (lifted panels only, below every panel)
##   Visual → Background, Ground+props, Content (objects), Ink (border)
## An erased panel (rubbed out by the artist, GDD §6 page 1.8) is no longer
## a room: no collision, no links, and it no longer takes up space on the
## page. Only a smudge and crumbs are left.

signal erase_finished

const HALFTONE := preload("res://shaders/halftone.gdshader")
## The artist's eraser rubs a panel out in rows, back and forth.
const ERASE_ROW := 16
const ERASE_ROW_SEC := 0.2
const ERASER_SIZE := Vector2(28, 14)

var panel_id := ""
var size := Vector2i.ZERO
## [{side: "left"|"right"|"top"|"bottom", from, to}] in panel-local offsets.
var openings: Array = []
## {} when fixed; otherwise {axis: "x"|"y", min, max} in page coordinates.
var track: Dictionary = {}
var pencil := false
var solids: Array[Rect2i] = []
var props: Array = []
var notes: Array = []
## Currently linked border gaps, from PanelLinks.gaps_for.
var gaps: Array = []
## Slots in this panel's captions: words written on the panel itself.
var caption_slots: Array[WordSlot] = []
var hovered := false
var selected := false
var dragging := false
var erased := false
## The scene this panel is in ("", "later", "night"), set by the page.
var scene := ""
## Whether a prop's `when` holds here (set by the page with the scene).
var _cond := func(_expr: String) -> bool: return true
var _scene_layer: DrawLayer

var visual: Node2D
var content: Node2D
var _border_body: StaticBody2D
var _ink: BakedLayer
var _ground: BakedLayer
var _shadow: DrawLayer
var _shake_t := 0.0
var _time := 0.0
var _solid_body: StaticBody2D
var _smudge: DrawLayer
## Rubbing progress, 0..1 across every row; -1 when not rubbing.
var _erase_p := -1.0
var _ducking := false
var _look := []


func setup(def: Dictionary) -> void:
	panel_id = def["id"]
	var r: Array = def["rect"]
	position = Vector2(r[0], r[1])
	size = Vector2i(int(r[2]), int(r[3]))
	openings = def.get("openings", [])
	track = def.get("track", {})
	pencil = def.get("pencil", false)
	props = def.get("props", [])
	notes = def.get("notes", [])
	for s: Array in def.get("solids", []):
		solids.append(Rect2i(int(s[0]), int(s[1]), int(s[2]), int(s[3])))
	_time = randf() * 10.0

	if is_lifted():
		_shadow = DrawLayer.make(_draw_shadow, -1)
		add_child(_shadow)

	_border_body = StaticBody2D.new()
	_border_body.name = "BorderBody"
	add_child(_border_body)
	_solid_body = StaticBody2D.new()
	_solid_body.name = "SolidBody"
	for s in solids:
		_add_box(_solid_body, Rect2(s))
	add_child(_solid_body)

	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	var bg := ColorRect.new()
	bg.size = Vector2(size)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: Dictionary = Palette.PANEL_STYLES.get(def.get("bg", "room_warm"), Palette.PANEL_STYLES["room_warm"])
	var mat := ShaderMaterial.new()
	mat.shader = HALFTONE
	mat.set_shader_parameter("paper", style["paper"])
	mat.set_shader_parameter("dot_color", style["dot"])
	mat.set_shader_parameter("spacing", style["spacing"])
	mat.set_shader_parameter("top", style["top"])
	mat.set_shader_parameter("bottom", style["bottom"])
	mat.set_shader_parameter("size", Vector2(size))
	bg.material = mat
	visual.add_child(bg)
	_ground = BakedLayer.make(_draw_ground, Rect2(Vector2.ZERO, Vector2(size)))
	visual.add_child(_ground)
	_scene_layer = DrawLayer.make(_draw_scene)
	visual.add_child(_scene_layer)
	content = Node2D.new()
	content.name = "Content"
	visual.add_child(content)
	# Chevrons and loose openings reach a few units outside the border.
	_ink = BakedLayer.make(_draw_ink, Rect2(Vector2(-10, -10), Vector2(size) + Vector2(20, 20)))
	visual.add_child(_ink)
	_rebuild_border()
	if def.get("erased", false):
		erase(false)


func is_lifted() -> bool:
	return not track.is_empty() and not erased


## A lifted panel obeys the words written on it (GDD §4.2): a heavy one
## (`mass` > 1) or a halted one lies flat on the page and won't slide.
func is_pinned() -> bool:
	for s in caption_slots:
		var def := WordLibrary.get_def(s.word)
		match def.get("category"):
			"halt":
				return true
			"mass":
				if float(def.get("mass", 1.0)) > 1.0:
					return true
	return false


func rect() -> Rect2i:
	return Rect2i(Vector2i(position.round()), size)


## Input for PanelLinks. Pencil sketches are never inked, so they never link.
func info() -> Dictionary:
	return {"id": panel_id, "rect": rect(), "openings": [] if pencil or erased else openings}


func encloses(r: Rect2) -> bool:
	return not erased and Rect2(rect()).encloses(r)


## Rubs the panel out. It stops being a room at once (collision off, no
## links); with `animate` the drawing is rubbed away row by row and
## `erase_finished` fires when the last row is done.
func erase(animate := true) -> void:
	if erased:
		return
	erased = true
	_border_body.collision_layer = 0
	_solid_body.collision_layer = 0
	if _shadow:
		_shadow.visible = false
	_smudge = DrawLayer.make(_draw_smudge)
	add_child(_smudge)
	if not animate:
		visual.visible = false
		return
	_set_ducking(true)
	_erase_p = 0.0
	var rows := _erase_rows()
	for i in rows:
		Audio.play("rub", 0.1)
		var tween := create_tween()
		tween.tween_method(_set_erase_p, float(i) / rows, float(i + 1) / rows, ERASE_ROW_SEC)
		await tween.finished
	_erase_p = -1.0
	visual.visible = false
	_smudge.queue_redraw()
	_set_ducking(false)
	erase_finished.emit()


func _erase_rows() -> int:
	return ceili(float(size.y) / ERASE_ROW)


func _set_erase_p(v: float) -> void:
	_erase_p = v
	_smudge.queue_redraw()


## The artist rubbing a panel out is the artist intervening: the music ducks
## until the last row is done (GDD §10). Let go if freed mid-rub (a reset).
func _set_ducking(on: bool) -> void:
	if on == _ducking:
		return
	_ducking = on
	if on:
		Audio.duck_hold()
	else:
		Audio.duck_release()


func _exit_tree() -> void:
	_set_ducking(false)


func set_gaps(new_gaps: Array) -> void:
	if new_gaps == gaps:
		return
	gaps = new_gaps
	_rebuild_border()
	_ink.refresh()


func shake() -> void:
	_shake_t = 0.3


func _process(delta: float) -> void:
	_time += delta
	if _shake_t > 0.0:
		_shake_t -= delta
		visual.position = Vector2(roundf(sin(_time * 70.0) * 2.0), 0) if _shake_t > 0.0 else Vector2.ZERO
	if is_lifted():
		# The shadow bobs every frame (one rect); the border only redraws
		# when the hand's state on it changes.
		_shadow.queue_redraw()
		var look := [hovered, selected, dragging, is_pinned()]
		if look != _look:
			_look = look
			_ink.refresh()


# --- collision -------------------------------------------------------------

func _add_box(body: StaticBody2D, r: Rect2) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	body.add_child(cs)


func _side_gaps(side: String) -> Array:
	var out := []
	for g: Dictionary in gaps:
		if g.side == side:
			out.append([int(g.from), int(g.to)])
	return out


## Border collision = the four sides minus linked gaps. Each side reaches
## PageConst.OUTER into the gutter so neighbouring borders seal it, leaving a
## tunnel exactly where a link opened both borders (TDD §3.4).
func _rebuild_border() -> void:
	for c in _border_body.get_children():
		_border_body.remove_child(c)
		c.queue_free()
	var w := size.x
	var h := size.y
	var o := PageConst.OUTER
	var b := PageConst.BORDER
	for seg: Array in PanelLinks.subtract_intervals(-o, w + o, _side_gaps("top")):
		_add_box(_border_body, Rect2(seg[0], -o, seg[1] - seg[0], o + b))
	for seg: Array in PanelLinks.subtract_intervals(-o, w + o, _side_gaps("bottom")):
		_add_box(_border_body, Rect2(seg[0], h - b, seg[1] - seg[0], o + b))
	for seg: Array in PanelLinks.subtract_intervals(-o, h + o, _side_gaps("left")):
		_add_box(_border_body, Rect2(-o, seg[0], o + b, seg[1] - seg[0]))
	for seg: Array in PanelLinks.subtract_intervals(-o, h + o, _side_gaps("right")):
		_add_box(_border_body, Rect2(w - b, seg[0], o + b, seg[1] - seg[0]))


# --- drawing ---------------------------------------------------------------

## What rubbing leaves: grey smears, crumbs along the bottom and a ghost of
## the border. While rubbing, the rows already done are covered with page
## paper and the eraser sits at the end of the current stroke.
func _draw_smudge(ci: CanvasItem) -> void:
	var rows := _erase_rows()
	var done := rows if _erase_p < 0.0 else int(_erase_p * rows)
	if _erase_p >= 0.0:
		ci.draw_rect(Rect2(0, 0, size.x, mini(done * ERASE_ROW, size.y)), Palette.PAGE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(panel_id)
	for i in done:
		for k in 2:
			var w := rng.randf_range(0.3, 0.7) * size.x
			var x := rng.randf_range(0.0, size.x - w)
			ci.draw_rect(Rect2(x, i * ERASE_ROW + rng.randi_range(3, ERASE_ROW - 4), w, 1), Color(Palette.PENCIL, 0.25))
	if done == rows:
		for i in int(size.x / 6.0):
			var c := Vector2(rng.randf_range(2.0, size.x - 4.0), size.y - rng.randf_range(1.0, 10.0))
			ci.draw_rect(Rect2(c.round(), Vector2(2, 1) if i % 3 else Vector2(1, 1)), Color(Palette.ERASER, 0.8))
		Ink.dashed(ci, Vector2(0, 0), size.x, 0, 1, Color(Palette.PENCIL, 0.3), 2, 6)
		Ink.dashed(ci, Vector2(0, size.y - 1), size.x, 0, 1, Color(Palette.PENCIL, 0.3), 2, 6)
		Ink.dashed(ci, Vector2(0, 0), size.y, 1, 1, Color(Palette.PENCIL, 0.3), 2, 6)
		Ink.dashed(ci, Vector2(size.x - 1, 0), size.y, 1, 1, Color(Palette.PENCIL, 0.3), 2, 6)
	if _erase_p < 0.0 or done >= rows:
		return
	# The current stroke, covered up to the eraser, boustrophedon.
	var f := _erase_p * rows - done
	var x := f * size.x if done % 2 == 0 else (1.0 - f) * size.x
	var y := done * ERASE_ROW
	var h := mini(ERASE_ROW, size.y - y)
	if done % 2 == 0:
		ci.draw_rect(Rect2(0, y, x, h), Palette.PAGE)
	else:
		ci.draw_rect(Rect2(x, y, size.x - x, h), Palette.PAGE)
	var e := Rect2(Vector2(x - ERASER_SIZE.x / 2.0, y + h / 2.0 - ERASER_SIZE.y / 2.0).round(), ERASER_SIZE)
	Ink.box(ci, e, Palette.ERASER)
	Ink.box(ci, Rect2(e.position + Vector2(10, 0), Vector2(12, ERASER_SIZE.y)), Palette.WHITE)


func _draw_shadow(ci: CanvasItem) -> void:
	var lift := 3.0
	if is_pinned():
		lift = 1.0
	elif not Settings.reduced_motion:
		lift += 2.0 if dragging else roundf(sin(_time * 2.2))
	ci.draw_rect(Rect2(Vector2(lift, lift + 1), Vector2(size)), Color(Palette.SHADOW, 0.85))


## The page tells the panel its scene and how to test prop conditions.
func set_scene(new_scene: String, cond: Callable) -> void:
	_cond = cond
	var changed := new_scene != scene
	scene = new_scene
	if changed or props.any(func(pr: Dictionary) -> bool: return pr.has("when")):
		_ground.refresh()
	_scene_layer.queue_redraw()


## Over the ground, under what is in the room: night washes the room dark
## (Nib, things and lettering stay readable on top); LATER leaves cobwebs.
func _draw_scene(ci: CanvasItem) -> void:
	if scene == "night":
		ci.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color(Palette.NIGHT_WASH, 0.62))
		var m := Vector2(size.x - 18, 18)
		Ink.dot(ci, m, 5.0, Color(Palette.WHITE, 0.9))
		Ink.dot(ci, m + Vector2(2.2, -1.2), 4.4, Color(Palette.NIGHT_WASH, 0.95))
	elif scene == "later":
		for k in 4:
			var r := 6.0 + k * 5.0
			Ink.stroke(ci, Ink.ellipse_points(Vector2(2, 2), Vector2(r, r), 6, 0.0, PI / 2.0), Color(Palette.SCENERY, 0.55), 0.5)
		for a in [0.2, 0.75, 1.3]:
			Ink.line(ci, Vector2(2, 2), Vector2(2, 2) + Vector2.from_angle(a) * 22.0, Color(Palette.SCENERY, 0.55), 0.5)


func _draw_ground(ci: CanvasItem) -> void:
	for p: Dictionary in props:
		if not _cond.call(p.get("when", "")):
			continue
		PropPainter.paint(ci, p)
	for s in solids:
		# Ground: what Nib stands on is inked heavily on top, hatched below.
		var r := Rect2(s)
		ci.draw_rect(r, Palette.PAPER_DARK)
		Ink.hatch(ci, r.grow_individual(0, -3, 0, 0), Palette.SHADOW)
		Ink.line(ci, r.position + Vector2(0, 1), Vector2(r.end.x, r.position.y + 1), Palette.INK, Ink.W_BORDER)
		Ink.line(ci, r.position + Vector2(0.5, 0), Vector2(r.position.x + 0.5, r.end.y), Palette.INK, 1.0)
		Ink.line(ci, Vector2(r.end.x - 0.5, r.position.y), Vector2(r.end.x - 0.5, r.end.y), Palette.INK, 1.0)
	for n: Dictionary in notes:
		var at: Array = n["at"]
		ComicFont.draw_lines(ci, Vector2(at[0], at[1]), n["text"], Palette.PENCIL)


func _openings_on(side: String) -> Array:
	var out := []
	if pencil:
		return out
	for op: Dictionary in openings:
		if op.side == side:
			out.append([int(op.from), int(op.to)])
	return out


func _draw_ink(ci: CanvasItem) -> void:
	var w := size.x
	var h := size.y
	if pencil:
		Ink.dashed(ci, Vector2(0, 0), w, 0, 0.8, Palette.PENCIL, 6, 2)
		Ink.dashed(ci, Vector2(0, h - 0.8), w, 0, 0.8, Palette.PENCIL, 6, 2)
		Ink.dashed(ci, Vector2(0, 0), h, 1, 0.8, Palette.PENCIL, 6, 2)
		Ink.dashed(ci, Vector2(w - 0.8, 0), h, 1, 0.8, Palette.PENCIL, 6, 2)
		return
	var b := PageConst.BORDER
	var color := Palette.RED if selected else Palette.INK
	# side: [axis, fixed offset, length]
	var sides := {"top": [0, 0, w], "bottom": [0, h - b, w], "left": [1, 0, h], "right": [1, w - b, h]}
	for side: String in sides:
		var spec: Array = sides[side]
		var ops := _openings_on(side)
		var gs := _side_gaps(side)
		var solid := PanelLinks.subtract_intervals(0, spec[2], ops + gs)
		for seg: Array in solid:
			_ink_segment(ci, spec, seg[0], seg[1], color)
		for op: Array in ops:
			# Loose ink: an unlinked opening is drawn as a dashed line.
			for seg: Array in PanelLinks.subtract_intervals(op[0], op[1], gs):
				var from := Vector2(seg[0], spec[1]) if spec[0] == 0 else Vector2(spec[1], seg[0])
				Ink.dashed(ci, from, seg[1] - seg[0], spec[0], b, color, 3.5, 2.5)
	if is_lifted() and not dragging and not is_pinned():
		_draw_track_arrows(ci)


func _ink_segment(ci: CanvasItem, spec: Array, a: int, z: int, color: Color) -> void:
	var b := PageConst.BORDER
	if spec[0] == 0:
		ci.draw_rect(Rect2(a, spec[1], z - a, b), color)
	else:
		ci.draw_rect(Rect2(spec[1], a, b, z - a), color)


## Chevrons on a movable panel's edges, pointing the way it slides. Always
## shown, so movable rooms read at a glance; red when the hand is on it.
func _draw_track_arrows(ci: CanvasItem) -> void:
	var c := Vector2(size) / 2.0
	var col := Palette.RED if (hovered or selected) else Color(Palette.INK, 0.7)
	var pairs := [[Vector2(c.x, -2.5), Vector2(0, -1)], [Vector2(c.x, size.y + 2.5), Vector2(0, 1)]] if track.get("axis") == "y" \
		else [[Vector2(-2.5, c.y), Vector2(-1, 0)], [Vector2(size.x + 2.5, c.y), Vector2(1, 0)]]
	for pr: Array in pairs:
		var base: Vector2 = pr[0]
		var d: Vector2 = pr[1]
		var n := Vector2(-d.y, d.x)
		for k in 2:
			var tip := base + d * (2.5 + k * 3.0)
			Ink.stroke(ci, PackedVector2Array([tip - d * 2.5 + n * 3.0, tip, tip - d * 2.5 - n * 3.0]), col, 1.2)
