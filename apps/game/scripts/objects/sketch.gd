class_name Sketch
extends StaticBody2D
## A pencil line the artist sketched but never inked (GDD §4.3). While drawn
## it is as solid as any line on the page; Nib's eraser rubs it out, which
## takes its collision away and leaves crumbs, and brushing crumbs back over
## the smudge draws it again. Ink is permanent and is never a Sketch.
##
## Node position = the sketch's top-left in panel space. `erased` in data
## starts it as a smudge, waiting for crumbs.

var sketch_id := ""
var size := Vector2.ZERO
## Crumbs that erasing leaves and restoring costs.
var crumbs := 1
var initially_drawn := true
var drawn := true
var panel: ComicPanel
var highlighted := false
var _shape: CollisionShape2D


func setup(def: Dictionary) -> void:
	sketch_id = def["id"]
	var r: Array = def["rect"]
	position = Vector2(r[0], r[1])
	size = Vector2(r[2], r[3])
	crumbs = int(def.get("crumbs", 1))
	initially_drawn = not def.get("erased", false)
	drawn = initially_drawn
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	_shape.disabled = not drawn
	add_child(_shape)


func rect() -> Rect2:
	return Rect2(global_position, size)


func set_drawn(value: bool) -> void:
	drawn = value
	_shape.set_deferred("disabled", not value)
	queue_redraw()


## What this sketch adds to the crumbs in hand: its crumbs once rubbed out,
## or minus them once a smudge that started erased is drawn back.
func crumb_balance() -> int:
	if drawn == initially_drawn:
		return 0
	return crumbs if initially_drawn else -crumbs


func _process(_delta: float) -> void:
	if highlighted:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var line := Palette.RED if highlighted else Palette.PENCIL
	if drawn:
		# Graphite: a light hatch inside a 1 px outline whose top stroke
		# overshoots the corners, the way a quick sketch does.
		Ink.hatch(self, r, Palette.SHADOW, 3)
		Ink.rect_outline(self, r, line)
		draw_rect(Rect2(-2, 0, size.x + 4, 1), line)
		return
	# A smudge: rubbed-out graphite, the ghost of its outline, and one dot
	# per crumb it takes to draw back.
	draw_rect(r, Color(Palette.PAGE_FIBER, 0.7))
	var ghost := Color(line, 0.6)
	Ink.dashed(self, Vector2(0, 0), size.x, 0, 1, ghost, 2, 3)
	Ink.dashed(self, Vector2(0, size.y - 1), size.x, 0, 1, ghost, 2, 3)
	Ink.dashed(self, Vector2(0, 0), size.y, 1, 1, ghost, 2, 3)
	Ink.dashed(self, Vector2(size.x - 1, 0), size.y, 1, 1, ghost, 2, 3)
	var dots := Vector2(size.x / 2.0 - (crumbs * 3 - 1) / 2.0, size.y / 2.0 - 1)
	for i in crumbs:
		draw_rect(Rect2(roundf(dots.x) + i * 3, roundf(dots.y), 2, 2), line)
