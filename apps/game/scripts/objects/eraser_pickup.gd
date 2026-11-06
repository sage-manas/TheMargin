class_name EraserPickup
extends Node2D
## The artist's eraser, left lying on the page (GDD §4.3: found, not
## given). Nib picks it up by walking into it; from then on the eraser is an
## ability (`progress.abilities`), so the page never draws it again.
##
## `at` is the point on the floor it lies on, in panel space.

const SIZE := Vector2(12, 6)

var eraser_id := ""
var page: ComicPage
var _time := 0.0


func setup(def: Dictionary) -> void:
	eraser_id = def["id"]
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])


func rect() -> Rect2:
	return Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func _physics_process(delta: float) -> void:
	_time += delta
	if not Settings.reduced_motion:
		queue_redraw()
	if page and page.player and page.player.collision_rect().intersects(rect()):
		page.find_eraser()
		queue_free()


func _draw() -> void:
	var r := Rect2(Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)
	# A rubber block in a paper sleeve, worn to a slant at one end.
	Ink.box(self, r, Palette.ERASER)
	Ink.box(self, Rect2(r.position + Vector2(5, 0), Vector2(5, SIZE.y)), Palette.WHITE)
	draw_rect(Rect2(r.position, Vector2(2, 1)), Palette.PAPER)
	# A glint, so a still object on a busy page still catches the eye.
	if Settings.reduced_motion or fmod(_time, 2.0) < 0.25:
		draw_rect(Rect2(r.position + Vector2(-3, -4), Vector2(1, 3)), Palette.RED)
		draw_rect(Rect2(r.position + Vector2(-4, -3), Vector2(3, 1)), Palette.RED)
