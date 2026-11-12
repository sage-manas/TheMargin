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
var _loose: DrawLayer
## The caption is static between changes, so its drawing is baked.
var _static: BakedLayer
var _look := ""


func setup(def: Dictionary) -> void:
	caption_id = def["id"]
	style = def.get("style", "narrator")
	text = def.get("text", "")
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_static = BakedLayer.make(_paint, Rect2())
	add_child(_static)
	if style == "narrator" and Lettering.has_slots(text):
		_lettering = Lettering.new()
		var r: Array = def.get("reach_at", [at[0] + 16, at[1] + 16])
		_lettering.parse(text, caption_id, self, self, Vector2(26, 40))
		for s in _lettering.slots:
			s.anchor_offset = Vector2(r[0], r[1]) - position
		slots = _lettering.slots
		_loose = DrawLayer.make(func(ci: CanvasItem) -> void: _lettering.draw(ci, Vector2(4, 3), 0.0, "loose"))
		add_child(_loose)
	_static.area = _area()


func on_slot_changed(_slot: WordSlot) -> void:
	_redraw()


func refresh(_animate := false) -> void:
	_redraw()


func _redraw() -> void:
	if _static:
		_static.refresh(_area())
	if _loose:
		_loose.queue_redraw()


func slot_prompt_position(slot: WordSlot) -> Vector2:
	return global_position + _lettering.slot_top(slot)


## Only the loose words move (by moving their layer); the caption redraws
## when its words or highlights change.
func _process(delta: float) -> void:
	if _lettering:
		_time += delta
		_loose.position.y = 0.0 if Settings.reduced_motion else sin(_time * 4.0) * 0.6
		var look := _lettering.look()
		if look != _look:
			_look = look
			_redraw()


func set_text_instant(t: String) -> void:
	if _lettering:
		push_warning("Caption %s holds words and cannot be rewritten" % caption_id)
		return
	text = t
	_visible_chars = -1
	_strike = 0.0
	_redraw()


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
	_redraw()


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
		_redraw()
		await get_tree().create_timer(CHAR_TIME * (2.0 if style == "artist" else 1.0)).timeout
	_visible_chars = -1
	_redraw()
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


## The caption's area for its baked drawing: the box, with room for a
## strike-through and the artist's larger, uneven lettering.
func _area() -> Rect2:
	var scale := 2 if style == "artist" else 1
	var lines := ComicFont.split_lines(text)
	var w := 16
	for l in lines:
		w = maxi(w, ComicFont.measure(l, true) * scale)
	if _lettering:
		w = maxi(w, _lettering.max_width())
	return Rect2(-2, -2, w + 14, lines.size() * ComicFont.LINE_HEIGHT * scale + 10)


func _paint(ci: CanvasItem) -> void:
	if text == "":
		return
	if _lettering:
		var box := Vector2(_lettering.width() + 8, _lettering.lines.size() * ComicFont.LINE_HEIGHT + 4)
		Ink.box(ci, Rect2(Vector2.ZERO, box), Palette.CAPTION, Palette.INK, 1.0)
		_lettering.draw(ci, Vector2(4, 3), 0.0, "static")
		return
	var scale := 2 if style == "artist" else 1
	var lines := ComicFont.split_lines(text)
	var width := 0
	for l in lines:
		width = maxi(width, ComicFont.measure(l) * scale)
	var size := Vector2(width + 8, lines.size() * ComicFont.LINE_HEIGHT * scale + 4)
	if style == "narrator":
		Ink.box(ci, Rect2(Vector2.ZERO, size), Palette.CAPTION, Palette.INK, 1.0)
	var color := Palette.PENCIL if style == "artist" else Palette.INK
	var shown := ComicFont.split_lines(_shown_text())
	for i in shown.size():
		var pos := Vector2(4, 3 + i * ComicFont.LINE_HEIGHT * scale)
		if style == "artist":
			# Hand-lettered: each character sits on a slightly uneven baseline.
			var x := 0.0
			for k in shown[i].length():
				var ch := shown[i][k]
				var jitter := 0.6 * sin(k * 2.3 + i * 1.7)
				x += ComicFont.draw(ci, pos + Vector2(x, jitter), ch, color, false, scale)
		else:
			ComicFont.draw(ci, pos, shown[i], color)
	if _strike > 0.0:
		for i in lines.size():
			var lw := ComicFont.measure(lines[i]) * scale
			var y := 6.5 + i * ComicFont.LINE_HEIGHT * scale
			Ink.line(ci, Vector2(3, y + 0.4), Vector2(3 + (lw + 2) * _strike, y - 0.4), Palette.RED, 1.0)
