class_name Caption
extends Node2D
## Narrator caption box (style "narrator") or the artist's scrawl ("artist").
## Captions can strike themselves out and be rewritten: the narrator noticing
## that the rules were broken (GDD §8).

const CHAR_TIME := 0.035

var caption_id := ""
var style := "narrator"
var text := ""
var _visible_chars := -1   # -1 = all
var _strike := 0.0         # 0..1 strike-through progress across the old text


func setup(def: Dictionary) -> void:
	caption_id = def["id"]
	style = def.get("style", "narrator")
	text = def.get("text", "")
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])


func set_text_instant(t: String) -> void:
	text = t
	_visible_chars = -1
	_strike = 0.0
	queue_redraw()


## Strikes out the current text, then letters the new text in.
func rewrite(new_text: String) -> void:
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


func _shown_text() -> String:
	if _visible_chars < 0:
		return text
	return text.substr(0, _visible_chars)


func _draw() -> void:
	if text == "":
		return
	var scale := 2 if style == "artist" else 1
	var lines := PixelFont.split_lines(text)
	var width := 0
	for l in lines:
		width = maxi(width, PixelFont.measure(l) * scale)
	var size := Vector2(width + 8, lines.size() * PixelFont.LINE_HEIGHT * scale + 4)
	if style == "narrator":
		Ink.box(self, Rect2(Vector2.ZERO, size), Palette.CAPTION)
	var color := Palette.PENCIL if style == "artist" else Palette.INK
	var shown := PixelFont.split_lines(_shown_text())
	for i in shown.size():
		var pos := Vector2(4, 3 + i * PixelFont.LINE_HEIGHT * scale)
		if style == "artist":
			# Hand-lettered: each character sits on a slightly uneven baseline.
			var x := 0
			for ci in shown[i].length():
				var ch := shown[i][ci]
				var jitter := 1 if (ci * 7 + i * 3) % 5 == 0 else 0
				x += PixelFont.draw(self, pos + Vector2(x, jitter), ch, color, false, scale)
		else:
			PixelFont.draw(self, pos, shown[i], color)
	if _strike > 0.0:
		for i in lines.size():
			var lw := PixelFont.measure(lines[i]) * scale
			draw_rect(Rect2(3, 6 + i * PixelFont.LINE_HEIGHT * scale, (lw + 2) * _strike, 1), Palette.RED)
