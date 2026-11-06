class_name ComicPanel
extends Node2D
## One comic panel: a room bounded by an ink border (GDD §4.1).
## Node position = panel top-left in page coordinates. Children:
##   BorderBody / SolidBody (physics, never shaken)
##   Shadow (lifted panels only, below every panel)
##   Visual → Background, Ground+props, Content (objects), Ink (border)

const HALFTONE := preload("res://shaders/halftone.gdshader")

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

var visual: Node2D
var content: Node2D
var _border_body: StaticBody2D
var _ink: DrawLayer
var _shadow: DrawLayer
var _shake_t := 0.0
var _time := 0.0


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
	var solid_body := StaticBody2D.new()
	solid_body.name = "SolidBody"
	for s in solids:
		_add_box(solid_body, Rect2(s))
	add_child(solid_body)

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
	visual.add_child(DrawLayer.make(_draw_ground))
	content = Node2D.new()
	content.name = "Content"
	visual.add_child(content)
	_ink = DrawLayer.make(_draw_ink)
	visual.add_child(_ink)
	_rebuild_border()


func is_lifted() -> bool:
	return not track.is_empty()


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
	return {"id": panel_id, "rect": rect(), "openings": [] if pencil else openings}


func encloses(r: Rect2) -> bool:
	return Rect2(rect()).encloses(r)


func set_gaps(new_gaps: Array) -> void:
	if new_gaps == gaps:
		return
	gaps = new_gaps
	_rebuild_border()
	_ink.queue_redraw()


func shake() -> void:
	_shake_t = 0.3


func _process(delta: float) -> void:
	_time += delta
	if _shake_t > 0.0:
		_shake_t -= delta
		visual.position = Vector2(roundf(sin(_time * 70.0) * 2.0), 0) if _shake_t > 0.0 else Vector2.ZERO
	if is_lifted():
		_shadow.queue_redraw()
		_ink.queue_redraw()


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

func _draw_shadow(ci: CanvasItem) -> void:
	var lift := 3.0
	if is_pinned():
		lift = 1.0
	elif not Settings.reduced_motion:
		lift += 2.0 if dragging else roundf(sin(_time * 2.2))
	ci.draw_rect(Rect2(Vector2(lift, lift + 1), Vector2(size)), Palette.SHADOW)


func _draw_ground(ci: CanvasItem) -> void:
	for p: Dictionary in props:
		PropPainter.paint(ci, p)
	for s in solids:
		var r := Rect2(s)
		ci.draw_rect(r, Palette.PAPER_DARK)
		Ink.hatch(ci, r.grow_individual(0, -3, 0, 0), Palette.SHADOW)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Palette.INK)
		ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), Palette.INK)
		ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), Palette.INK)
	for n: Dictionary in notes:
		var at: Array = n["at"]
		PixelFont.draw_lines(ci, Vector2(at[0], at[1]), n["text"], Palette.PENCIL)


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
		Ink.dashed(ci, Vector2(0, 0), w, 0, 1, Palette.PENCIL, 6, 2)
		Ink.dashed(ci, Vector2(0, h - 1), w, 0, 1, Palette.PENCIL, 6, 2)
		Ink.dashed(ci, Vector2(0, 0), h, 1, 1, Palette.PENCIL, 6, 2)
		Ink.dashed(ci, Vector2(w - 1, 0), h, 1, 1, Palette.PENCIL, 6, 2)
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
				Ink.dashed(ci, from, seg[1] - seg[0], spec[0], b, color, 3, 3)
	if is_lifted() and (hovered or selected) and not dragging and not is_pinned():
		_draw_track_arrows(ci)


func _ink_segment(ci: CanvasItem, spec: Array, a: int, z: int, color: Color) -> void:
	var b := PageConst.BORDER
	if spec[0] == 0:
		ci.draw_rect(Rect2(a, spec[1], z - a, b), color)
	else:
		ci.draw_rect(Rect2(spec[1], a, b, z - a), color)


func _draw_track_arrows(ci: CanvasItem) -> void:
	var c := Vector2(size) / 2.0
	var col := Palette.RED
	if track.get("axis") == "y":
		for i in 3:
			ci.draw_rect(Rect2(c.x - i, -6 + i, i * 2 + 1, 1), col)
			ci.draw_rect(Rect2(c.x - i, size.y + 5 - i, i * 2 + 1, 1), col)
	else:
		for i in 3:
			ci.draw_rect(Rect2(-6 + i, c.y - i, 1, i * 2 + 1), col)
			ci.draw_rect(Rect2(size.x + 5 - i, c.y - i, 1, i * 2 + 1), col)
