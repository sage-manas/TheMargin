class_name PlayerInteraction
extends Node2D
## Picks the word slot in reach and resolves take / place / swap (TDD §3.6).
## Knows nothing about doors or bubbles beyond the WordSlot interface.

var page: ComicPage
var player: Player
var carrying := ""
var target: WordSlot
var verb := ""


func setup(owner_page: ComicPage, owner_player: Player, carried: String) -> void:
	page = owner_page
	player = owner_player
	carrying = carried
	player.carrying = carried
	z_index = 20


func _process(_delta: float) -> void:
	_refresh_target()
	queue_redraw()


func _refresh_target() -> void:
	var best: WordSlot = null
	var best_d := INF
	var best_verb := ""
	if player.can_act():
		var here := page.player_panel()
		for s: WordSlot in page.slots.values():
			if s.panel != here:
				continue
			var d := s.anchor() - player.global_position
			if absf(d.x) > s.reach.x or absf(d.y) > s.reach.y:
				continue
			var v := WordSlot.verb_for(carrying, s.word, s.loose, carrying != "" and s.accepts_word(carrying))
			if v != "" and absf(d.x) < best_d:
				best = s
				best_d = absf(d.x)
				best_verb = v
	if target and target != best:
		target.highlighted = false
	target = best
	verb = best_verb
	if target:
		target.highlighted = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and target:
		perform()
		get_viewport().set_input_as_handled()


func perform() -> bool:
	if target == null:
		return false
	var slot := target
	match verb:
		"take":
			carrying = slot.take()
			Audio.play("take")
			EventBus.word_taken.emit(slot.id, carrying)
		"place":
			var w := carrying
			carrying = ""
			slot.put(w)
			Audio.play("place")
			EventBus.word_placed.emit(slot.id, w)
		"swap":
			var old := slot.take()
			var w := carrying
			carrying = old
			slot.put(w)
			Audio.play("place")
			Audio.play("take")
			EventBus.word_taken.emit(slot.id, old)
			EventBus.word_placed.emit(slot.id, w)
		_:
			return false
	player.carrying = carrying
	EventBus.state_dirty.emit()
	return true


func _draw() -> void:
	if target == null:
		return
	var p := to_local(target.prompt_position())
	var label := verb.to_upper()
	if verb != "take":
		label += " " + carrying
	var w := PixelFont.measure(label) + 14
	var r := Rect2(roundf(p.x - w / 2.0), p.y - 12, w, 11)
	Ink.box(self, r, Palette.WHITE)
	Ink.box(self, Rect2(r.position + Vector2(2, 2), Vector2(7, 7)), Palette.INK, Palette.INK)
	PixelFont.draw(self, r.position + Vector2(3, 2), "E", Palette.WHITE)
	PixelFont.draw(self, r.position + Vector2(11, 2), label, Palette.INK)
