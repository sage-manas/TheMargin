class_name Npc
extends Node2D
## A drawn character. Stands at its feet position; blinks; can show a short
## thought ("...?", "!") above its head when the story reacts to the player.

var npc_id := ""
var _frames: Array[Texture2D] = []
var _blink := 0.0
var _emote := ""
var _emote_t := 0.0


func setup(def: Dictionary) -> void:
	npc_id = def["id"]
	_frames = Sprites.frames(def.get("sprite", "neighbor"))
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_blink = randf_range(1.5, 3.5)


func emote(text: String, duration := 3.0) -> void:
	_emote = text
	_emote_t = duration
	Audio.play("emote")
	queue_redraw()


func _process(delta: float) -> void:
	_blink -= delta
	if _blink < -0.14:
		_blink = randf_range(2.0, 4.5)
	if _emote_t > 0.0:
		_emote_t -= delta
		if _emote_t <= 0.0:
			_emote = ""
	queue_redraw()


func _draw() -> void:
	var tex := _frames[1 if _blink < 0.0 and _frames.size() > 1 else 0]
	var sz := tex.get_size()
	draw_texture(tex, Vector2(-roundf(sz.x / 2.0), -sz.y))
	if _emote != "":
		var w := PixelFont.measure(_emote) + 6
		var r := Rect2(roundf(-w / 2.0) - 8, -sz.y - 16, w, 11)
		Ink.rounded_box(self, r, Palette.BUBBLE)
		# Thought-bubble dots trailing down to the head.
		draw_rect(Rect2(r.position.x + w - 3, r.end.y + 1, 2, 2), Palette.INK)
		draw_rect(Rect2(r.position.x + w - 1, r.end.y + 4, 1, 1), Palette.INK)
		PixelFont.draw(self, r.position + Vector2(3, 2), _emote, Palette.INK)
