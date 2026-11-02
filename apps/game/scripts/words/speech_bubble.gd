class_name SpeechBubble
extends Node2D
## A speech bubble whose bold words are slots. Text syntax:
##   "THIS DOOR WON'T *OPEN*.|NOT ONCE."  — "|" breaks lines, *WORD* is a
##   loose word, ** is an empty gap. Each slot gets id "<bubble id>:<n>".

const PAD := Vector2i(4, 4)
const GAP_WIDTH := 16

var bubble_id := ""
var speaker: Node2D
var slots: Array[WordSlot] = []
## lines → segments: {"text": String} or {"slot": int}
var _lines: Array = []
var _slot_rects := {}   # slot index -> Rect2 (local)
var _time := 0.0


func setup(def: Dictionary, speaker_node: Node2D) -> void:
	bubble_id = def["id"]
	speaker = speaker_node
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_parse(def["text"])


func _parse(text: String) -> void:
	var re := RegEx.create_from_string("\\*([A-Z]*)\\*")
	for line in PixelFont.split_lines(text):
		var segs := []
		var cursor := 0
		for m in re.search_all(line):
			if m.get_start() > cursor:
				segs.append({"text": line.substr(cursor, m.get_start() - cursor)})
			var idx := slots.size()
			var s := WordSlot.make("%s:%d" % [bubble_id, idx], m.get_string(1), true, [], self, speaker)
			s.reach = Vector2(26, 40)
			slots.append(s)
			segs.append({"slot": idx})
			cursor = m.get_end()
		if cursor < line.length():
			segs.append({"text": line.substr(cursor)})
		_lines.append(segs)


func on_slot_changed(_slot: WordSlot) -> void:
	queue_redraw()


func refresh(_animate := false) -> void:
	queue_redraw()


func slot_prompt_position(slot: WordSlot) -> Vector2:
	var r: Rect2 = _slot_rects.get(slots.find(slot), Rect2())
	return global_position + Vector2(r.get_center().x, r.position.y - 2)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _segment_width(seg: Dictionary) -> int:
	if seg.has("text"):
		return PixelFont.measure(seg["text"]) + 1
	var w: String = slots[seg["slot"]].word
	return (PixelFont.measure(w, true) if w != "" else GAP_WIDTH) + 1


func _draw() -> void:
	var width := 0
	for segs: Array in _lines:
		var lw := 0
		for seg: Dictionary in segs:
			lw += _segment_width(seg)
		width = maxi(width, lw)
	var size := Vector2(width + PAD.x * 2, _lines.size() * PixelFont.LINE_HEIGHT + PAD.y * 2 - 2)
	var rect := Rect2(Vector2.ZERO, size)

	# Tail pointing toward the speaker's head (but stopping well short of it),
	# drawn first so the bubble covers its base.
	var target := speaker.position + Vector2(0, -24) - position
	var tx := clampf(target.x, 6.0, size.x - 6.0)
	var base_y := size.y - 1
	var head := (Vector2(tx, base_y) + (target - Vector2(tx, base_y)).limit_length(12.0)).round()
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, base_y), Vector2(tx + 3, base_y), head]), Palette.BUBBLE)
	Ink.line(self, Vector2i(int(tx - 3), int(base_y)), Vector2i(head), Palette.INK)
	Ink.line(self, Vector2i(int(tx + 3), int(base_y)), Vector2i(head), Palette.INK)
	Ink.rounded_box(self, rect, Palette.BUBBLE)
	draw_rect(Rect2(tx - 2, base_y, 5, 1), Palette.BUBBLE)

	var bob := 0.0 if Settings.reduced_motion else roundf(sin(_time * 4.0) * 0.6)
	for li in _lines.size():
		var x := float(PAD.x)
		var y := float(PAD.y + li * PixelFont.LINE_HEIGHT)
		for seg: Dictionary in _lines[li]:
			var w := _segment_width(seg)
			if seg.has("text"):
				PixelFont.draw(self, Vector2(x, y), seg["text"], Palette.INK)
			else:
				var slot: WordSlot = slots[seg["slot"]]
				_slot_rects[seg["slot"]] = Rect2(x - 1, y - 1, w + 1, PixelFont.HEIGHT + 2)
				if slot.word != "":
					var oy := bob if slot.loose else 0.0
					if slot.highlighted:
						Ink.rect_outline(self, Rect2(x - 2, y - 2 + oy, w + 2, PixelFont.HEIGHT + 4), Palette.RED)
					PixelFont.draw(self, Vector2(x, y + oy), slot.word, Palette.RED if slot.loose else Palette.INK, true)
				else:
					var c := Palette.RED if slot.highlighted else Palette.PENCIL
					draw_rect(Rect2(x, y + PixelFont.HEIGHT - 1, GAP_WIDTH, 1), c)
			x += w
