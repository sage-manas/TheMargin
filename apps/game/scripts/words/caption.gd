class_name Caption
extends Node2D
## Narrator caption box (style "narrator") or the artist's scrawl ("artist").
## Captions can strike themselves out and be rewritten: the narrator noticing
## that the rules were broken (GDD §8).
## A narrator caption may also hold bold words (Lettering syntax): words
## written on a panel, which the panel obeys (GDD §4.2). Such captions are
## fixed text; Nib reaches their words from `reach_at` (panel-local, usually
## a spot on the floor below).
## The artist lettering a caption is the artist intervening: the music ducks
## until the last letter is down (GDD §10).

const CHAR_TIME := 0.035

var caption_id := ""
var style := "narrator"
var text := ""
var _visible_chars := -1   # -1 = all
var _strike := 0.0         # 0..1 strike-through progress across the old text
var slots: Array[WordSlot] = []
var _lettering: Lettering
var _time := 0.0
var _ducking := false


func setup(def: Dictionary) -> void:
	caption_id = def["id"]
	style = def.get("style", "narrator")
	text = def.get("text", "")
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	if style == "narrator" and Lettering.has_slots(text):
		_lettering = Lettering.new()
		var r: Array = def.get("reach_at", [at[0] + 16, at[1] + 16])
		_lettering.parse(text, caption_id, self, self, Vector2(26, 40))
		for s in _lettering.slots:
			s.anchor_offset = Vector2(r[0], r[1]) - position
		slots = _lettering.slots


func on_slot_changed(_slot: WordSlot) -> void:
	queue_redraw()


func refresh(_animate := false) -> void:
	queue_redraw()


func slot_prompt_position(slot: WordSlot) -> Vector2:
	return global_position + _lettering.slot_top(slot)


func _process(delta: float) -> void:
	if _lettering:
		_time += delta
		queue_redraw()


func set_text_instant(t: String) -> void:
	if _lettering:
		push_warning("Caption %s holds words and cannot be rewritten" % caption_id)
		return
	text = t
	_visible_chars = -1
	_strike = 0.0
	queue_redraw()


## Strikes out the current text, then letters the new text in.
func rewrite(new_text: String) -> void:
	if _lettering:
		push_warning("Caption %s holds words and cannot be rewritten" % caption_id)
		return
	_set_ducking(style == "artist")
	var tween := create_tween()
	tween.tween_method(_set_strike, 0.0, 1.0, 0.5)
	Audio.play("scratch")
	await tween.finished
	await get_tree().create_timer(0.35).timeout
	_strike = 0.0
	await write(new_text)


func _set_strike(v: float) -> void:
	_strike = v
	queue_redraw()


## Letters text in one character at a time.
func write(new_text: String) -> void:
	if _lettering:
		push_warning("Caption %s holds words and cannot be rewritten" % caption_id)
		return
	_set_ducking(style == "artist")
	text = new_text
	_visible_chars = 0
	var total := text.length()
	while _visible_chars < total:
		_visible_chars += 1
		if _visible_chars % 4 == 1 and text[_visible_chars - 1] != " ":
			Audio.play("scratch", 0.1, -6.0)
		queue_redraw()
		await get_tree().create_timer(CHAR_TIME * (2.0 if style == "artist" else 1.0)).timeout
	_visible_chars = -1
	queue_redraw()
	_set_ducking(false)


## Holds the music duck at most once, and lets go if the caption is freed
## mid-sentence (a page reset), so a hold never leaks.
func _set_ducking(on: bool) -> void:
	if on == _ducking:
		return
	_ducking = on
	if on:
		Audio.duck_hold()
	else:
		Audio.duck_release()


func _exit_tree() -> void:
	_set_ducking(false)


func _shown_text() -> String:
	if _visible_chars < 0:
		return text
	return text.substr(0, _visible_chars)


func _draw() -> void:
	if text == "":
		return
	if _lettering:
		var box := Vector2(_lettering.width() + 8, _lettering.lines.size() * ComicFont.LINE_HEIGHT + 4)
		Ink.box(self, Rect2(Vector2.ZERO, box), Palette.CAPTION, Palette.INK, 1.0)
		_lettering.draw(self, Vector2(4, 3), 0.0 if Settings.reduced_motion else sin(_time * 4.0) * 0.6)
		return
	var scale := 2 if style == "artist" else 1
	var lines := ComicFont.split_lines(text)
	var width := 0
	for l in lines:
		width = maxi(width, ComicFont.measure(l) * scale)
	var size := Vector2(width + 8, lines.size() * ComicFont.LINE_HEIGHT * scale + 4)
	if style == "narrator":
		Ink.box(self, Rect2(Vector2.ZERO, size), Palette.CAPTION, Palette.INK, 1.0)
	var color := Palette.PENCIL if style == "artist" else Palette.INK
	var shown := ComicFont.split_lines(_shown_text())
	for i in shown.size():
		var pos := Vector2(4, 3 + i * ComicFont.LINE_HEIGHT * scale)
		if style == "artist":
			# Hand-lettered: each character sits on a slightly uneven baseline.
			var x := 0.0
			for ci in shown[i].length():
				var ch := shown[i][ci]
				var jitter := 0.6 * sin(ci * 2.3 + i * 1.7)
				x += ComicFont.draw(self, pos + Vector2(x, jitter), ch, color, false, scale)
		else:
			ComicFont.draw(self, pos, shown[i], color)
	if _strike > 0.0:
		for i in lines.size():
			var lw := ComicFont.measure(lines[i]) * scale
			var y := 6.5 + i * ComicFont.LINE_HEIGHT * scale
			Ink.line(self, Vector2(3, y + 0.4), Vector2(3 + (lw + 2) * _strike, y - 0.4), Palette.RED, 1.0)
