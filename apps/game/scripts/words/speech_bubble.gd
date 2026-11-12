class_name SpeechBubble
extends Node2D
## A speech bubble whose bold words are slots (syntax in Lettering), e.g.
##   "THIS DOOR WON'T *OPEN*.|NOT ONCE."
## With no speaker the bubble has fallen (page 1.6): nobody says it any more,
## so it lies on the floor as a thing, solid enough to stand on, with its
## words reached from on top. A fallen bubble's `at` is the floor point under
## its bottom-left corner, and its size is fixed at the widest its words can
## make it, so swapping a word never moves the ground under Nib.

const PAD := Vector2(4, 4)
## Nib, plus the carried word floating over their head.
const PROMPT_ABOVE_NIB := 30.0

var bubble_id := ""
var speaker: Node2D
var slots: Array[WordSlot] = []
var fallen := false
var _text := Lettering.new()
var _time := 0.0
var _size := Vector2.ZERO


func setup(def: Dictionary, speaker_node: Node2D) -> void:
	bubble_id = def["id"]
	speaker = speaker_node
	fallen = speaker == null
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_text.parse(def["text"], bubble_id, self, speaker if speaker else self, Vector2(26, 40))
	slots = _text.slots
	if fallen:
		_size = Vector2(_text.max_width() + PAD.x * 2, _text_height())
		position.y -= _size.y
		for s in slots:
			s.anchor_offset = Vector2(PAD.x + _text.slot_center(s).x, 0)
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = _size
		cs.shape = shape
		cs.position = _size / 2.0
		body.add_child(cs)
		add_child(body)


func _text_height() -> float:
	return _text.lines.size() * ComicFont.LINE_HEIGHT + PAD.y * 2 - 2


## The fallen bubble's footprint, in page coordinates.
func rect() -> Rect2:
	return Rect2(global_position, _size)


func on_slot_changed(_slot: WordSlot) -> void:
	queue_redraw()


func refresh(_animate := false) -> void:
	queue_redraw()


func slot_prompt_position(slot: WordSlot) -> Vector2:
	if fallen:
		# Nib reads a fallen bubble standing on it: prompt above the carried word.
		return global_position + slot.anchor_offset + Vector2(0, -PROMPT_ABOVE_NIB)
	return global_position + _text.slot_top(slot)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var bob := 0.0 if Settings.reduced_motion else sin(_time * 4.0) * 0.6
	if fallen:
		_draw_fallen(bob)
		return
	var size := Vector2(_text.width() + PAD.x * 2, _text_height())
	var rect := Rect2(Vector2.ZERO, size)

	# Tail pointing toward the speaker's head (but stopping well short of it),
	# drawn first so the bubble covers its base.
	var target := speaker.position + Vector2(0, -24) - position
	var tx := clampf(target.x, 6.0, size.x - 6.0)
	var base_y := size.y - 1
	var head := Vector2(tx, base_y) + (target - Vector2(tx, base_y)).limit_length(12.0)
	# A curved tail, the way a letterer pulls it from the balloon.
	var mid := Vector2(tx, base_y).lerp(head, 0.5) + Vector2(1.5, 0)
	var tail := PackedVector2Array([Vector2(tx - 3.5, base_y), mid + Vector2(-1, 0), head, mid + Vector2(1.5, -1), Vector2(tx + 3.5, base_y)])
	draw_colored_polygon(tail, Palette.BUBBLE)
	Ink.stroke(self, tail, Palette.INK, 1.0)
	Ink.rounded_box(self, rect, Palette.BUBBLE, Palette.INK, 5.0, 1.0)
	draw_rect(Rect2(tx - 2.6, base_y - 1.2, 5.2, 2.0), Palette.BUBBLE)
	_text.draw(self, Vector2(PAD), bob)


## Lying on its side: the tail, pointing at nobody, flat on the floor.
func _draw_fallen(bob: float) -> void:
	var y := _size.y - 0.5
	var tail := PackedVector2Array([Vector2(8, y - 4), Vector2(-10, y), Vector2(8, y)])
	draw_colored_polygon(tail, Palette.BUBBLE)
	Ink.stroke(self, tail, Palette.INK, 1.0)
	Ink.rounded_box(self, Rect2(Vector2.ZERO, _size), Palette.BUBBLE, Palette.INK, 5.0, Ink.W_THING)
	_text.draw(self, Vector2(PAD), bob)
