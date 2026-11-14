class_name PlateButton
extends Node2D
## A pressure plate set into the floor (GDD §4.2). It is pressed while the
## weight resting on it reaches what it needs: Nib weighs 1, a crate weighs
## what its label says (`mass`, 1 as drawn), and Nib riding a crate adds to
## that crate. Its own label also accepts `mass` and scales what it needs:
## a LIGHT plate gives under anything, a HEAVY one only under real weight.
##
## The plate has no collision; things stand on the floor beneath it. `at`
## is the left end of the floor line it sits on, in panel space.

signal changed(pressed: bool)

const SIZE := Vector2(32, 3)
## How close to the floor line a bottom edge must be to rest on the plate.
const TOLERANCE := 1.0

var button_id := ""
var needs := 1.0
var pressed := false
var slot: WordSlot
var page: ComicPage


func setup(def: Dictionary) -> void:
	button_id = def["id"]
	needs = float(def.get("needs", 1.0))
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	slot = WordSlot.make("%s:label" % button_id, def.get("label", ""), def.get("loose", true), ["mass"], self, self, Vector2(SIZE.x / 2.0, 0))
	slot.reach = Vector2(22, 12)


## What the plate needs before it gives: `needs`, scaled by its label.
func threshold() -> float:
	var def := WordLibrary.get_def(slot.word)
	var factor := float(def.get("mass", 1.0)) if def.get("category") == "mass" else 1.0
	return needs * factor


## The weight resting on the plate right now.
func load_on() -> float:
	if page == null:
		return 0.0
	var total := 0.0
	var nib := page.player
	if nib != null and _rests(nib.collision_rect()):
		total += 1.0
	for c: Crate in page.crates.values():
		if _rests(c.rect()):
			total += c.weight()
			if nib != null and c.carries(nib):
				total += 1.0
	return total


func _rests(r: Rect2) -> bool:
	var floor_y := global_position.y
	return absf(r.end.y - floor_y) <= TOLERANCE and r.end.x > global_position.x and r.position.x < global_position.x + SIZE.x


## Re-reads the plate. `animate` is false while a page is being built or
## restored, so no sounds or events fire.
func refresh(animate := true) -> void:
	var want := load_on() >= threshold() - 0.001
	if want != pressed:
		pressed = want
		if animate:
			Audio.play("place" if pressed else "blip", 0.05, -4.0)
			if pressed:
				EventBus.button_pressed.emit(button_id)
			else:
				EventBus.button_released.emit(button_id)
		changed.emit(pressed)
		queue_redraw()


func on_slot_changed(_slot: WordSlot) -> void:
	queue_redraw()
	refresh(true)


func slot_prompt_position(_s: WordSlot) -> Vector2:
	return global_position + Vector2(SIZE.x / 2.0, -14)


func _physics_process(_delta: float) -> void:
	refresh(true)
	if slot.loose and slot.word != "" and not Settings.reduced_motion:
		queue_redraw()


func _draw() -> void:
	# A pressure plate: the housing is set into the floor; the plate sits
	# proud until pressed, with a chevron saying "press".
	var housing := Rect2(-2, -1, SIZE.x + 4, 3)
	Ink.box(self, housing, Palette.NIGHT, Palette.INK, 1.0)
	var rise := 1.0 if pressed else SIZE.y
	var plate := Rect2(0, -rise, SIZE.x, rise + 1)
	Ink.rounded_box(self, plate, Palette.RED if pressed else Palette.OCHRE, Palette.INK, 1.0, Ink.W_THING)
	if not pressed:
		var c := Vector2(SIZE.x / 2.0, -rise - 3.0)
		Ink.stroke(self, PackedVector2Array([c + Vector2(-2.5, -1.5), c, c + Vector2(2.5, -1.5)]), Color(Palette.INK, 0.55), 0.8)
	# The label is stencilled on the floor below the plate.
	LabelTag.draw(self, Vector2(SIZE.x / 2.0, 3), slot, 16.0)
