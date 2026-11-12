class_name PageControl
extends Node2D
## Something too small for Nib to work: a lever or a combination dial drawn
## in a panel. The reader works it through a close-up (GDD §4.8). Each
## control is a switch: a lever is on when pulled; a dial is on while it
## shows its code.
##
##   {type: "lever", id, at, on?}
##   {type: "dial",  id, at, code: "417"}

signal changed(on: bool)

var control_id := ""
var kind := ""
var lever_on := false
var code := ""
## The dial's wheels, one digit each.
var digits: Array[int] = []


func setup(def: Dictionary) -> void:
	control_id = def["id"]
	kind = def["type"]
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	if kind == "lever":
		lever_on = bool(def.get("on", false))
	else:
		code = str(def["code"])
		for i in code.length():
			digits.append(0)


func is_on() -> bool:
	return lever_on if kind == "lever" else value() == code


## What the save keeps: the lever's position or the dial's digits.
func value() -> Variant:
	if kind == "lever":
		return lever_on
	var s := ""
	for d in digits:
		s += str(d)
	return s


func apply_value(v: Variant) -> void:
	if kind == "lever" and v is bool:
		lever_on = v
	elif kind == "dial" and v is String and v.length() == digits.size() and v.is_valid_int():
		for i in v.length():
			digits[i] = int(v[i])
	queue_redraw()


func pull() -> void:
	var was := is_on()
	lever_on = not lever_on
	Audio.play("place")
	_after(was)


func turn(wheel: int, step: int) -> void:
	var was := is_on()
	digits[wheel] = wrapi(digits[wheel] + step, 0, 10)
	Audio.play("blip")
	_after(was)


func _after(was: bool) -> void:
	queue_redraw()
	EventBus.state_dirty.emit()
	if is_on() != was:
		if is_on() and kind == "dial":
			Audio.play("chime")
		changed.emit(is_on())


## In the panel the control is drawn small: a detail, not something Nib can use.
func _draw() -> void:
	if kind == "lever":
		Ink.box(self, Rect2(-3, -2, 6, 4), Palette.muted(Palette.NIGHT, 0.2), Palette.INK, 0.8)
		var tip := Vector2(3.5 if lever_on else -3.5, -7)
		Ink.line(self, Vector2.ZERO, tip, Palette.INK, 1.0)
		Ink.dot(self, tip, 1.2, Palette.RED)
	else:
		Ink.rounded_box(self, Rect2(-digits.size() * 2.5 - 1, -4, digits.size() * 5 + 2, 7), Palette.muted(Palette.NIGHT, 0.2), Palette.INK, 1.0, 0.8)


## The magnified drawing inside a close-up of radius `r` centred on the
## origin. Lever: the handle and its slot. Dial: one wheel per digit, with
## arrows above and below. `hot` is the part under the hand (-1 for none).
func draw_closeup(ci: CanvasItem, r: float, hot: int) -> void:
	if kind == "lever":
		var plate := Rect2(-r * 0.25, r * 0.15, r * 0.5, r * 0.35)
		Ink.rounded_box(ci, plate, Palette.NIGHT, Palette.INK, 2.0, Ink.W_THING)
		var pivot := Vector2(0, r * 0.3)
		var tip := pivot + Vector2(r * 0.45 if lever_on else -r * 0.45, -r * 0.55)
		Ink.line(ci, pivot, tip, Palette.INK, 3.0)
		Ink.line(ci, pivot, tip, Palette.SCENERY, 1.5)
		Ink.ellipse(ci, tip, Vector2(3.2, 3.2), Palette.RED if hot == 0 else Palette.muted(Palette.RED, 0.15), Palette.INK, Ink.W_THING)
		ComicFont.draw_centered(ci, 0, r * 0.55, "ON" if lever_on else "OFF", Palette.INK, true)
		return
	var n := digits.size()
	var w := 12.0
	var x0 := -n * w / 2.0
	for i in n:
		var cell := Rect2(x0 + i * w + 1, -7, w - 2, 14)
		Ink.rounded_box(ci, cell, Palette.WHITE, Palette.RED if hot == i else Palette.INK, 2.0, Ink.W_THING if hot == i else 1.0)
		ComicFont.draw_centered(ci, cell.get_center().x, -3.5, str(digits[i]), Palette.INK, true)
		var col := Palette.RED if hot == i else Palette.SCENERY
		Ink.arrowhead(ci, Vector2(cell.get_center().x, -12), Vector2(0, -1), 3.0, col)
		Ink.arrowhead(ci, Vector2(cell.get_center().x, 12), Vector2(0, 1), 3.0, col)
	if is_on():
		ComicFont.draw_centered(ci, 0, r * 0.5, "CLICK", Palette.RED, true)


## Which part of the magnified control a close-up-local point is on:
## [0, 0] for the lever; [wheel, +1 or -1] for a dial; null for nothing.
func hit(p: Vector2, r: float) -> Variant:
	if kind == "lever":
		return [0, 0] if p.length() < r * 0.9 else null
	var n := digits.size()
	var w := 12.0
	var i := int(floor((p.x + n * w / 2.0) / w))
	if i < 0 or i >= n or absf(p.y) > 16.0:
		return null
	return [i, -1 if p.y > 0.0 else 1]
