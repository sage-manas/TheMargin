class_name Sketch
extends StaticBody2D
## A pencil line the artist sketched but never inked (GDD §4.3, §4.4).
## While drawn it is as solid as any line on the page, unless it is `faint`:
## a layout line too light to stand on. Nib's eraser rubs pencil out, which
## takes its collision away and leaves crumbs, and brushing crumbs back over
## the smudge draws it again. A sketch with an `ink` cost can be traced with
## ink from Nib's hat: it becomes ink, solid and permanent, and the eraser
## no longer touches it.
##
## Node position = the sketch's top-left in panel space. `erased` in data
## starts it as a smudge, waiting for crumbs.

var sketch_id := ""
var size := Vector2.ZERO
## Crumbs that erasing leaves and restoring costs.
var crumbs := 1
## Drops of ink tracing costs; 0 means it can't be traced.
var ink_cost := 0
var faint := false
var initially_drawn := true
var drawn := true
var inked := false
var panel: ComicPanel
## Tools currently pointing at this sketch.
var _highlighters := {}
var _shape: CollisionShape2D


func setup(def: Dictionary) -> void:
	sketch_id = def["id"]
	var r: Array = def["rect"]
	position = Vector2(r[0], r[1])
	size = Vector2(r[2], r[3])
	crumbs = int(def.get("crumbs", 1))
	ink_cost = int(def.get("ink", 0))
	faint = def.get("faint", false)
	initially_drawn = not def.get("erased", false)
	drawn = initially_drawn
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	_shape.disabled = not is_solid()
	add_child(_shape)


func rect() -> Rect2:
	return Rect2(global_position, size)


func traceable() -> bool:
	return ink_cost > 0


## Whether this sketch is solid once drawn (faint pencil only once inked).
func solid_when_drawn() -> bool:
	return inked or not faint


func is_solid() -> bool:
	return drawn and solid_when_drawn()


func set_drawn(value: bool) -> void:
	drawn = value
	if not value:
		inked = false
	_apply()


func set_inked() -> void:
	drawn = true
	inked = true
	_apply()


## Back to how the artist drew it.
func reset() -> void:
	drawn = initially_drawn
	inked = false
	_apply()


## The save form (SAVE_SCHEMA §2): true drawn, false erased, "inked".
func state() -> Variant:
	return "inked" if inked else drawn


func apply_state(v: Variant) -> void:
	if v is bool:
		set_drawn(v)
	elif v == "inked" and traceable():
		set_inked()


func _apply() -> void:
	_shape.set_deferred("disabled", not is_solid())
	queue_redraw()


## What this sketch adds to the crumbs in hand: its crumbs once rubbed out,
## or minus them once a smudge that started erased is drawn back.
func crumb_balance() -> int:
	if drawn == initially_drawn:
		return 0
	return crumbs if initially_drawn else -crumbs


## Ink this sketch has taken from Nib's hat.
func ink_spent() -> int:
	return ink_cost if inked else 0


func highlight(by: Object) -> void:
	_highlighters[by] = true
	queue_redraw()


func unhighlight(by: Object) -> void:
	_highlighters.erase(by)
	queue_redraw()


func is_highlighted() -> bool:
	return not _highlighters.is_empty()


func _process(_delta: float) -> void:
	if is_highlighted():
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var line := Palette.RED if is_highlighted() else Palette.PENCIL
	if inked:
		# Ink: drawn like the page's own ground, a 2 px line over hatching.
		draw_rect(r, Palette.PAPER_DARK)
		Ink.hatch(self, r, Palette.SHADOW)
		Ink.rect_outline(self, r, Palette.INK, 2 if size.x > 4 and size.y > 4 else 1)
		draw_rect(Rect2(0, 0, size.x, minf(2, size.y)), Palette.INK)
		return
	if drawn:
		if faint:
			# Layout pencil: a dashed outline round a pale tint, nothing in it
			# to stand on.
			draw_rect(r, Color(line, 0.18))
			Ink.dashed(self, Vector2(0, 0), size.x, 0, 1, line, 2, 2)
			Ink.dashed(self, Vector2(0, size.y - 1), size.x, 0, 1, line, 2, 2)
			Ink.dashed(self, Vector2(0, 0), size.y, 1, 1, line, 2, 2)
			Ink.dashed(self, Vector2(size.x - 1, 0), size.y, 1, 1, line, 2, 2)
		else:
			# Graphite: a light hatch inside a 1 px outline whose top stroke
			# overshoots the corners, the way a quick sketch does.
			Ink.hatch(self, r, Palette.SHADOW, 3)
			Ink.rect_outline(self, r, line)
			draw_rect(Rect2(-2, 0, size.x + 4, 1), line)
		_draw_dots(ink_cost, Palette.INK, -3)
		return
	# A smudge: rubbed-out graphite, the ghost of its outline, and one dot
	# per crumb it takes to draw back.
	draw_rect(r, Color(Palette.PAGE_FIBER, 0.7))
	var ghost := Color(line, 0.6)
	Ink.dashed(self, Vector2(0, 0), size.x, 0, 1, ghost, 2, 3)
	Ink.dashed(self, Vector2(0, size.y - 1), size.x, 0, 1, ghost, 2, 3)
	Ink.dashed(self, Vector2(0, 0), size.y, 1, 1, ghost, 2, 3)
	Ink.dashed(self, Vector2(size.x - 1, 0), size.y, 1, 1, ghost, 2, 3)
	_draw_dots(crumbs, line, size.y / 2.0 - 1)


## A row of `n` 2 px dots centred on the sketch, its top at `y`: crumbs on
## a smudge, or the ink cost just above a traceable sketch (GDD §4.4).
func _draw_dots(n: int, color: Color, y: float) -> void:
	var x := size.x / 2.0 - (n * 3 - 1) / 2.0
	for i in n:
		draw_rect(Rect2(roundf(x) + i * 3, roundf(y), 2, 2), color)
