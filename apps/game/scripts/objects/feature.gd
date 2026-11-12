class_name Feature
extends Node2D
## A part of a panel that is only there in some scenes or while a switch is
## on (GDD §4.7, §4.8). `when` is a Conditions expression; while it holds,
## the feature is active: drawn as itself and, if it is solid, collidable.
##
##   {id, kind, rect: [x, y, w, h], when, text?}
##
## Kinds:
##   vine        grows up from a sprout; its leaves are one-way ledges
##   ice         a solid block; when inactive it is a puddle
##   gate        solid bars; when inactive they are raised out of the way
##   bridge      a drawbridge plank across a gap; when inactive it stands up
##               at the left end of the gap
##   glow_steps  one-way ledges painted in glow paint (rect = the first
##               step; `steps` of them climb STEP_RISE each, `advance` units
##               apart to the right, overlapping when advance < width)
##   glow_text   writing in glow paint (`text`, rect = where it is written)

signal changed(active: bool)

const LEAF_GAP := 18.0
const LEAF := Vector2(12, 3)
const STEP_RISE := 18.0

var feature_id := ""
var kind := ""
var rect := Rect2()
var when := ""
var text := ""
var steps := 1
var advance := 0.0
var active := false
var _set := false
var _body: StaticBody2D
## 0..1 while growing or melting, for the drawing only.
var _shown := 0.0


func setup(def: Dictionary) -> void:
	feature_id = def["id"]
	kind = def["kind"]
	when = def.get("when", "")
	text = def.get("text", "")
	steps = int(def.get("steps", 1))
	var r: Array = def["rect"]
	rect = Rect2(r[0], r[1], r[2], r[3])
	advance = float(def.get("advance", rect.size.x))
	_body = StaticBody2D.new()
	_body.collision_layer = 0
	for s in solid_rects():
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = s.size
		cs.shape = shape
		cs.position = s.get_center()
		cs.one_way_collision = kind in ["vine", "glow_steps"]
		_body.add_child(cs)
	add_child(_body)


func is_solid() -> bool:
	return kind in ["vine", "ice", "gate", "glow_steps", "bridge"]


## Rects (panel-local) that collide while active.
func solid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	match kind:
		"vine":
			# Leaves alternate sides up the stalk, LEAF_GAP apart, the first
			# one LEAF_GAP above the ground.
			var y := rect.end.y - LEAF_GAP
			var left := true
			while y >= rect.position.y:
				var x := rect.position.x if left else rect.end.x - LEAF.x
				out.append(Rect2(Vector2(x, y), LEAF))
				left = not left
				y -= LEAF_GAP
		"ice", "gate", "bridge":
			out.append(rect)
		"glow_steps":
			for i in steps:
				out.append(Rect2(rect.position + Vector2(i * advance, -i * STEP_RISE), rect.size))
	return out


func set_active(on: bool, animate := true) -> void:
	if _set and on == active:
		return
	_set = true
	active = on
	_body.collision_layer = 1 if on and is_solid() else 0
	if animate and not Settings.reduced_motion:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: _shown = v; queue_redraw(), _shown, 1.0 if on else 0.0, 0.6)
	else:
		_shown = 1.0 if on else 0.0
	queue_redraw()
	changed.emit(on)


## Whether `r` (panel-local) overlaps what this would make solid.
func would_block(r: Rect2) -> bool:
	if not is_solid():
		return false
	for s in solid_rects():
		if s.intersects(r):
			return true
	return false


func _draw() -> void:
	match kind:
		"vine":
			_draw_vine()
		"ice":
			_draw_ice()
		"gate":
			_draw_gate()
		"bridge":
			_draw_bridge()
		"glow_steps":
			_draw_glow_steps()
		"glow_text":
			if _shown > 0.0:
				var c := Color(Palette.GLOW, _shown)
				ComicFont.draw_lines(self, rect.position + Vector2(-0.4, -0.4), text, Color(Palette.GLOW, _shown * 0.35), true, 1.0)
				ComicFont.draw_lines(self, rect.position, text, c, true)


func _draw_vine() -> void:
	var base := Vector2(rect.get_center().x, rect.end.y)
	# A sprout is always there; LATER it is a vine all the way up.
	var top_y := lerpf(rect.end.y - 10.0, rect.position.y, _shown)
	var stalk := PackedVector2Array()
	var y := base.y
	while y > top_y:
		stalk.append(Vector2(base.x + sin(y * 0.25) * 2.0, y))
		y -= 3.0
	stalk.append(Vector2(base.x + sin(top_y * 0.25) * 2.0, top_y))
	Ink.stroke(self, stalk, Palette.INK, Ink.W_THING + 0.5)
	Ink.stroke(self, stalk, Palette.LEAF, Ink.W_THING - 0.5)
	if _shown < 0.05:
		for d in [-1.0, 1.0]:
			_leaf(Vector2(base.x, base.y - 8), Vector2(d * 4.0, -2.0))
		return
	for s in solid_rects():
		if s.position.y < top_y:
			continue
		var stem := Vector2(base.x + sin(s.position.y * 0.25) * 2.0, s.position.y + 1.5)
		var tip := Vector2(s.get_center().x + (s.size.x / 2.0 if s.position.x > base.x - 1 else -s.size.x / 2.0), s.position.y + 1.0)
		# A leaf is a ledge: heavy ink on top so it reads as something to stand on.
		var leaf := PackedVector2Array([stem, (stem + tip) / 2.0 + Vector2(0, -2.2), tip, (stem + tip) / 2.0 + Vector2(0, 2.0)])
		Ink.shape(self, leaf, Palette.LEAF, Palette.INK, Ink.W_THING)


func _leaf(at: Vector2, dir: Vector2) -> void:
	var pts := PackedVector2Array([at, at + dir * 0.5 + Vector2(0, -2), at + dir, at + dir * 0.5 + Vector2(0, 1.5)])
	Ink.shape(self, pts, Palette.LEAF, Palette.INK, 0.8)


func _draw_ice() -> void:
	if _shown > 0.0:
		var r := Rect2(Vector2(rect.position.x, rect.end.y - rect.size.y * _shown), Vector2(rect.size.x, rect.size.y * _shown))
		Ink.rounded_box(self, r, Color(Palette.ICE, 0.95), Palette.INK, 2.0, Ink.W_THING)
		Ink.line(self, r.position + Vector2(3, 4), r.position + Vector2(8, 3), Palette.WHITE, 1.0)
		Ink.line(self, r.position + Vector2(3, 8), r.position + Vector2(5, 7), Palette.WHITE, 1.0)
	if _shown < 1.0:
		# The puddle it melts into.
		var w := rect.size.x * (1.2 - 0.4 * _shown)
		Ink.ellipse(self, Vector2(rect.get_center().x, rect.end.y - 0.8), Vector2(w / 2.0, 1.4), Color(Palette.ICE, 0.8), Palette.SCENERY, 0.6)


func _draw_gate() -> void:
	# Raised, the bars hang above the opening; lowered, they fill it.
	var drop := rect.size.y * _shown
	var top := rect.position.y - rect.size.y + drop
	_draw_groove()
	var bars := maxi(2, int(rect.size.x / 6.0))
	for i in bars + 1:
		var x := rect.position.x + rect.size.x * i / bars
		Ink.line(self, Vector2(x, top), Vector2(x, top + rect.size.y), Palette.INK, Ink.W_THING)
	Ink.line(self, Vector2(rect.position.x, top + rect.size.y - 1.0), Vector2(rect.end.x, top + rect.size.y - 1.0), Palette.INK, Ink.W_BORDER)
	Ink.line(self, Vector2(rect.position.x, top + 4.0), Vector2(rect.end.x, top + 4.0), Palette.INK, 1.0)


## Lowered, a plank across the gap; raised, it stands up at the left edge,
## hinged there, with its chain.
func _draw_bridge() -> void:
	var hinge := Vector2(rect.position.x, rect.position.y)
	var angle := lerpf(-PI / 2.0, 0.0, _shown)
	var along := Vector2.from_angle(angle)
	var across := Vector2(-along.y, along.x)
	var plank := PackedVector2Array([hinge, hinge + along * rect.size.x, hinge + along * rect.size.x + across * rect.size.y, hinge + across * rect.size.y])
	Ink.shape(self, plank, Palette.OCHRE, Palette.INK, Ink.W_THING)
	for k in range(1, int(rect.size.x / 12.0)):
		var a := hinge + along * (k * 12.0)
		Ink.line(self, a, a + across * rect.size.y, Palette.WOOD_DARK, 0.6)
	Ink.line(self, hinge + along * rect.size.x, hinge + Vector2(0, -rect.size.x * 0.9), Palette.SCENERY, 0.7)
	Ink.dot(self, hinge, 1.4, Palette.INK)


func _draw_groove() -> void:
	# The groove the gate runs in, on both sides of the opening.
	for x in [rect.position.x - 1.0, rect.end.x + 1.0]:
		Ink.line(self, Vector2(x, rect.position.y - rect.size.y), Vector2(x, rect.end.y), Palette.SCENERY, 1.0)


func _draw_glow_steps() -> void:
	for s in solid_rects():
		if _shown > 0.0:
			Ink.rounded_box(self, s.grow(1.0), Color(Palette.GLOW, 0.25 * _shown), Color(Palette.GLOW, 0.0), 2.0, 0.1)
			Ink.rounded_box(self, s, Color(Palette.GLOW, _shown), Color(Palette.INK, _shown), 1.0, 1.0)
		else:
			# By day the glow paint is a faint chalk mark: nothing to stand on.
			Ink.line(self, s.position + Vector2(1, s.size.y / 2.0), Vector2(s.end.x - 1, s.position.y + s.size.y / 2.0), Color(Palette.PENCIL, 0.35), 0.6)
