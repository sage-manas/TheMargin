class_name InkDrop
extends Node2D
## Ink to collect (GDD §4.4): a spilled drop, or a leaking inkwell holding a
## few. Nib collects it by walking into it, if the hat has room for all of
## it; otherwise it stays where it is. Collected pickups are saved by id
## (`pages.<id>.collected`), so ink in the hat can be derived on load.
##
## `at` is the point on the floor it sits on, in panel space.

const SIZE := Vector2(8, 8)
const WELL_SIZE := Vector2(12, 12)

var drop_id := ""
var drops := 1
var page: ComicPage
## Nib is touching it but the hat has no room.
var refused := false
var _time := 0.0


func setup(def: Dictionary) -> void:
	drop_id = def["id"]
	drops = int(def.get("drops", 1))
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_time = randf() * 2.0


func is_well() -> bool:
	return drops > 1


func rect() -> Rect2:
	var s := WELL_SIZE if is_well() else SIZE
	return Rect2(global_position + Vector2(-s.x / 2.0, -s.y), s)


func _physics_process(delta: float) -> void:
	_time += delta
	if not Settings.reduced_motion:
		queue_redraw()
	var touching := page != null and page.player != null and page.player.collision_rect().intersects(rect())
	if touching and page.collect_ink(self):
		queue_free()
		return
	if touching != refused:
		refused = touching
		if refused:
			Audio.play("deny", 0.0, -8.0)
		queue_redraw()


func _draw() -> void:
	var bob := 0.0 if Settings.reduced_motion else roundf(sin(_time * 3.0) * 0.6)
	if refused:
		PixelFont.draw_centered(self, 0, -28, "HAT FULL", Palette.PENCIL)
	if is_well():
		# A tipped inkwell, its spill pooling on the floor, one dot per drop.
		Ink.box(self, Rect2(-5, -10, 10, 10), Palette.BLUE_LIGHT)
		draw_rect(Rect2(-3, -12, 6, 2), Palette.INK)
		draw_rect(Rect2(-4, -6, 8, 5), Palette.INK)
		draw_rect(Rect2(4, -1, 6, 1), Palette.INK)
		for i in drops:
			draw_rect(Rect2(-(drops * 3 - 1) / 2.0 + i * 3, -16 + bob, 2, 2), Palette.INK)
		return
	# A single drop: a teardrop of ink with a glint.
	draw_rect(Rect2(-1, -8 + bob, 2, 2), Palette.INK)
	draw_rect(Rect2(-2, -6 + bob, 4, 2), Palette.INK)
	draw_rect(Rect2(-3, -4 + bob, 6, 3), Palette.INK)
	draw_rect(Rect2(-1, -4 + bob, 1, 1), Palette.WHITE)
	draw_rect(Rect2(-2, 0, 4, 1), Palette.SHADOW)
