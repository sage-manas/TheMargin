class_name Door
extends Node2D
## A door that obeys its label (GDD §4.2). Responds to the `state` word
## category; with no label it is as drawn (closed unless `open` in data).
## A door wired to a button (`"button": "<id>"`) stands open while that
## button is held down, unless a label says otherwise.
## An exit door turns the page when the character walks through it open.

const SIZE := Vector2(24, 32)

var door_id := ""
var exit := false
var default_open := false
var is_open := false
## Id of the button that holds this door open, if any.
var button_id := ""
var powered := false
var slot: WordSlot
var _shape: CollisionShape2D
var _swing := 0.0   # 0 closed, 1 fully open (visual only)


func setup(def: Dictionary) -> void:
	door_id = def["id"]
	exit = def.get("exit", false)
	default_open = def.get("open", false)
	button_id = def.get("button", "")
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	var body := StaticBody2D.new()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	_shape.shape = rect
	_shape.position = SIZE / 2.0
	body.add_child(_shape)
	add_child(body)
	slot = WordSlot.make("%s:label" % door_id, def.get("label", ""), def.get("loose", true), ["state"], self, self, Vector2(SIZE.x / 2.0, SIZE.y))
	slot.reach = Vector2(22, 12)
	refresh(false)


## Re-applies the current label. `animate` is false when restoring a save so
## no events or sounds replay.
func refresh(animate := true) -> void:
	var want := default_open or powered
	if slot.word != "":
		var def := WordLibrary.get_def(slot.word)
		if def.get("category") == "state":
			want = def.get("open", default_open)
	_set_open(want, animate)
	queue_redraw()


func on_slot_changed(_slot: WordSlot) -> void:
	refresh(true)


func set_powered(v: bool, animate := true) -> void:
	powered = v
	refresh(animate)


func _set_open(v: bool, animate: bool) -> void:
	var changed := v != is_open
	is_open = v
	_shape.set_deferred("disabled", v)
	if not animate:
		_swing = 1.0 if v else 0.0
		return
	if changed:
		Audio.play("door")
		if v:
			EventBus.door_opened.emit(door_id)


func doorway_rect() -> Rect2:
	return Rect2(global_position + Vector2(6, 4), Vector2(SIZE.x - 12, SIZE.y - 4))


func slot_prompt_position(_s: WordSlot) -> Vector2:
	return global_position + Vector2(SIZE.x / 2.0, -16)


func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	if _swing != target:
		_swing = move_toward(_swing, target, delta * 3.0)
		queue_redraw()
	if slot.loose and slot.word != "" and not Settings.reduced_motion:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, SIZE)
	# The doorway behind the leaf: dark, with the curled corner of the next
	# page glowing inside once it opens.
	Ink.box(self, r.grow(1.5), Palette.NIGHT, Palette.INK, Ink.W_THING + 0.5)
	if _swing > 0.0:
		var corner := PackedVector2Array([Vector2(SIZE.x - 3, SIZE.y - 13), Vector2(SIZE.x - 3, SIZE.y - 1), Vector2(SIZE.x - 15, SIZE.y - 1)])
		draw_colored_polygon(corner, Color(Palette.PAGE, _swing))
		Ink.stroke(self, corner, Color(Palette.INK, _swing * 0.6), 0.6, true)
	# The leaf swings toward the viewer: it narrows as it opens.
	var leaf_w := SIZE.x * (1.0 - _swing)
	if leaf_w >= 1.0:
		var leaf := Rect2(0.5, 0.5, leaf_w - 0.5, SIZE.y - 1.0)
		Ink.box(self, leaf, Palette.OCHRE, Palette.INK, Ink.W_THING)
		if leaf_w > 10:
			# Two recessed panels and a knob.
			var pw := leaf_w - 9.0
			Ink.stroke(self, Ink.round_rect_points(Rect2(leaf.position.x + 4, 4, pw, 10), 1.5), Palette.WOOD_DARK, 0.8, true)
			Ink.stroke(self, Ink.round_rect_points(Rect2(leaf.position.x + 4, 17, pw, 11), 1.5), Palette.WOOD_DARK, 0.8, true)
			Ink.dot(self, Vector2(leaf.end.x - 3.0, SIZE.y / 2.0 + 1.0), 1.1, Palette.INK)
	# A wired door has a lamp on its frame, lit while its button is held.
	if button_id != "":
		var lamp := Vector2(SIZE.x + 5, 6)
		if powered:
			Ink.dot(self, lamp, 3.4, Color(Palette.RED, 0.25))
		Ink.ellipse(self, lamp, Vector2(2.2, 2.2), Palette.RED if powered else Palette.muted(Palette.PENCIL, 0.3), Palette.INK, 0.8)
		Ink.line(self, Vector2(SIZE.x + 1.5, 6), Vector2(SIZE.x + 2.8, 6), Palette.INK, 0.8)
	# The label hangs from two nails above the door.
	var tag := LabelTag.draw(self, Vector2(SIZE.x / 2.0, -14), slot, 28.0)
	for x in [tag.position.x + 4, tag.end.x - 4]:
		Ink.line(self, Vector2(x, tag.end.y), Vector2(x, -1.5), Palette.PENCIL, 0.6)
