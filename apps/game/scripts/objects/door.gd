class_name Door
extends Node2D
## A door that obeys its label (GDD §4.2). Responds to the `state` word
## category; with no label it is as drawn (closed unless `open` in data).
## An exit door turns the page when the character walks through it open.

const SIZE := Vector2(24, 32)

var door_id := ""
var exit := false
var default_open := false
var is_open := false
var slot: WordSlot
var _shape: CollisionShape2D
var _swing := 0.0   # 0 closed, 1 fully open (visual only)


func setup(def: Dictionary) -> void:
	door_id = def["id"]
	exit = def.get("exit", false)
	default_open = def.get("open", false)
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
	var want := default_open
	if slot.word != "":
		var def := WordLibrary.get_def(slot.word)
		if def.get("category") == "state":
			want = def.get("open", default_open)
	_set_open(want, animate)
	queue_redraw()


func on_slot_changed(_slot: WordSlot) -> void:
	refresh(true)


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
	# Frame and the doorway behind the leaf: dark, with the curled corner of
	# the next page glowing inside.
	Ink.box(self, r.grow(1), Palette.NIGHT, Palette.INK, 2)
	if _swing > 0.0:
		var corner := PackedVector2Array([Vector2(SIZE.x - 3, SIZE.y - 13), Vector2(SIZE.x - 3, SIZE.y - 1), Vector2(SIZE.x - 15, SIZE.y - 1)])
		draw_colored_polygon(corner, Color(Palette.PAGE, _swing))
	# The leaf swings toward the viewer: it narrows as it opens.
	var leaf_w := roundf(SIZE.x * (1.0 - _swing))
	if leaf_w >= 1.0:
		var leaf := Rect2(1, 1, leaf_w - 1, SIZE.y - 2)
		Ink.box(self, leaf, Palette.OCHRE)
		if leaf_w > 8:
			draw_rect(Rect2(leaf.position.x + 4, 6, 1, SIZE.y - 10), Palette.SHADOW)
			draw_rect(Rect2(leaf.position.x + leaf_w - 6, 6, 1, SIZE.y - 10), Palette.SHADOW)
			draw_rect(Rect2(leaf.end.x - 5, SIZE.y / 2.0, 2, 2), Palette.INK)

	# Label plate above the door.
	var bold := slot.word != ""
	var w := maxi(PixelFont.measure(slot.word, true) + 6, 28) if bold else 28
	var plate := Rect2(roundf(SIZE.x / 2.0 - w / 2.0), -13, w, 11)
	Ink.box(self, plate, Palette.WHITE, Palette.RED if slot.highlighted else Palette.INK)
	if bold:
		var bob := 0.0 if (Settings.reduced_motion or not slot.loose) else roundf(sin(Time.get_ticks_msec() / 250.0) * 0.6)
		PixelFont.draw_centered(self, SIZE.x / 2.0, plate.position.y + 2 + bob, slot.word, Palette.RED if slot.loose else Palette.INK, true)
	else:
		draw_rect(Rect2(plate.position.x + 6, plate.position.y + 8, w - 12, 1), Palette.PENCIL)
