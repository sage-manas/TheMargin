class_name Hud
extends Control
## Minimal in-game HUD: only the hold-to-reset progress and the panel-mode
## banner. Everything else is shown in the world itself.

var reset_progress := 0.0
var panel_mode := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if reset_progress > 0.0:
		var w := 120.0
		var r := Rect2(320 - w / 2.0, 3, w, 10)
		Ink.rounded_box(self, r, Palette.WHITE, Palette.INK, 3.0, 0.9)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((w - 2) * reset_progress, 8)), Palette.CAPTION)
		Ink.stroke(self, Ink.round_rect_points(r.grow(-0.45), 3.0), Palette.INK, 0.9, true)
		ComicFont.draw_centered(self, 320, 5, "RESETTING PAGE", Palette.INK)
	elif panel_mode:
		ComicFont.draw_centered(self, 320, 5, "READER'S HAND: ARROWS MOVE, E PULLS, Q NEXT / DONE", Palette.RED)
