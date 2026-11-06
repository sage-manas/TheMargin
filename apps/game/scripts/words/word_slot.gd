class_name WordSlot
extends RefCounted
## A place that holds at most one word: a token in a speech bubble or the
## label of an object. The holder (bubble, door, …) reacts in
## on_slot_changed(slot) and positions the interaction prompt.

var id: String
var word := ""
## Loose words can be taken. Words placed by the player are always loose.
var loose := true
## Accepted word categories; empty means anything (sentence gaps).
var accepts: Array = []
## Optional per-word check on top of `accepts`, for holders that take only
## some words of a category (a platform takes only motion along its rail).
var filter := Callable()
var holder: Object
## Where the character must stand to reach this slot.
var anchor_node: Node2D
var anchor_offset := Vector2.ZERO
var reach := Vector2(22, 36)
## Panel that contains the slot; the character must be in the same panel.
var panel: Node2D
var highlighted := false


static func make(slot_id: String, initial: String, is_loose: bool, accepted: Array, owner: Object, anchor: Node2D, offset := Vector2.ZERO) -> WordSlot:
	var s := WordSlot.new()
	s.id = slot_id
	s.word = initial
	s.loose = is_loose
	s.accepts = accepted
	s.holder = owner
	s.anchor_node = anchor
	s.anchor_offset = offset
	return s


func anchor() -> Vector2:
	return anchor_node.global_position + anchor_offset


func prompt_position() -> Vector2:
	return holder.slot_prompt_position(self)


func accepts_word(w: String) -> bool:
	if not (accepts.is_empty() or WordLibrary.category(w) in accepts):
		return false
	return not filter.is_valid() or filter.call(w)


func take() -> String:
	var w := word
	word = ""
	holder.on_slot_changed(self)
	return w


func put(w: String) -> void:
	word = w
	loose = true
	holder.on_slot_changed(self)


## What interacting would do, from the hand and slot state (TDD §3.6).
## Returns "take", "place", "swap" or "".
static func verb_for(carrying: String, slot_word: String, slot_loose: bool, accepts_carried: bool) -> String:
	if carrying == "":
		return "take" if slot_word != "" and slot_loose else ""
	if not accepts_carried:
		return ""
	if slot_word == "":
		return "place"
	return "swap" if slot_loose else ""
