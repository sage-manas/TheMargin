class_name SpeechBubble
extends Node2D
## A speech bubble whose bold words are slots (syntax in Lettering), e.g.
##   "THIS DOOR WON'T *OPEN*.|NOT ONCE."

const PAD := Vector2i(4, 4)

var bubble_id := ""
var speaker: Node2D
var slots: Array[WordSlot] = []
var _text := Lettering.new()
var _time := 0.0


func setup(def: Dictionary, speaker_node: Node2D) -> void:
	bubble_id = def["id"]
	speaker = speaker_node
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_text.parse(def["text"], bubble_id, self, speaker, Vector2(26, 40))
	slots = _text.slots


func on_slot_changed(_slot: WordSlot) -> void:
	queue_redraw()


func refresh(_animate := false) -> void:
	queue_redraw()


func slot_prompt_position(slot: WordSlot) -> Vector2:
	return global_position + _text.slot_top(slot)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var size := Vector2(_text.width() + PAD.x * 2, _text.lines.size() * PixelFont.LINE_HEIGHT + PAD.y * 2 - 2)
	var rect := Rect2(Vector2.ZERO, size)

	# Tail pointing toward the speaker's head (but stopping well short of it),
	# drawn first so the bubble covers its base.
	var target := speaker.position + Vector2(0, -24) - position
	var tx := clampf(target.x, 6.0, size.x - 6.0)
	var base_y := size.y - 1
	var head := (Vector2(tx, base_y) + (target - Vector2(tx, base_y)).limit_length(12.0)).round()
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, base_y), Vector2(tx + 3, base_y), head]), Palette.BUBBLE)
	Ink.line(self, Vector2i(int(tx - 3), int(base_y)), Vector2i(head), Palette.INK)
	Ink.line(self, Vector2i(int(tx + 3), int(base_y)), Vector2i(head), Palette.INK)
	Ink.rounded_box(self, rect, Palette.BUBBLE)
	draw_rect(Rect2(tx - 2, base_y, 5, 1), Palette.BUBBLE)

	var bob := 0.0 if Settings.reduced_motion else roundf(sin(_time * 4.0) * 0.6)
	_text.draw(self, Vector2(PAD), bob)
