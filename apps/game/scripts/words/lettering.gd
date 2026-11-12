class_name Lettering
extends RefCounted
## Comic lettering whose bold words are slots, shared by speech bubbles and
## captions. Text syntax: "|" breaks lines, *WORD* is a loose word, ** is an
## empty gap. Each slot gets id "<owner id>:<n>".

const GAP_WIDTH := 16
const SLOT_RE := "\\*([A-Z]*)\\*"

var slots: Array[WordSlot] = []
## lines → segments: {"text": String} or {"slot": int}
var lines: Array = []
var _slot_rects := {}   # slot index -> Rect2 (owner-local)


static func has_slots(text: String) -> bool:
	return RegEx.create_from_string(SLOT_RE).search(text) != null


func parse(text: String, owner_id: String, holder: Object, anchor: Node2D, reach: Vector2) -> void:
	var re := RegEx.create_from_string(SLOT_RE)
	for line in ComicFont.split_lines(text):
		var segs := []
		var cursor := 0
		for m in re.search_all(line):
			if m.get_start() > cursor:
				segs.append({"text": line.substr(cursor, m.get_start() - cursor)})
			var idx := slots.size()
			var s := WordSlot.make("%s:%d" % [owner_id, idx], m.get_string(1), true, [], holder, anchor)
			s.reach = reach
			slots.append(s)
			segs.append({"slot": idx})
			cursor = m.get_end()
		if cursor < line.length():
			segs.append({"text": line.substr(cursor)})
		lines.append(segs)


func segment_width(seg: Dictionary) -> int:
	if seg.has("text"):
		return ComicFont.measure(seg["text"]) + 1
	var w: String = slots[seg["slot"]].word
	return (ComicFont.measure(w, true) if w != "" else GAP_WIDTH) + 1


func width() -> int:
	var out := 0
	for segs: Array in lines:
		var lw := 0
		for seg: Dictionary in segs:
			lw += segment_width(seg)
		out = maxi(out, lw)
	return out


## The widest this lettering can get, whatever word each slot holds.
func max_width() -> int:
	var widest := GAP_WIDTH
	for w: String in WordLibrary.all_words():
		widest = maxi(widest, ComicFont.measure(w, true))
	var out := 0
	for segs: Array in lines:
		var lw := 0
		for seg: Dictionary in segs:
			lw += (ComicFont.measure(seg["text"]) if seg.has("text") else widest) + 1
		out = maxi(out, lw)
	return out


## Top-centre of a slot as currently laid out, in lettering space.
func slot_center(slot: WordSlot) -> Vector2:
	var idx := slots.find(slot)
	for li in lines.size():
		var x := 0
		for seg: Dictionary in lines[li]:
			var w := segment_width(seg)
			if seg.get("slot", -1) == idx:
				return Vector2(x + w / 2.0, li * ComicFont.LINE_HEIGHT)
			x += w
	return Vector2.ZERO


## Where the interaction prompt goes for `slot`, in owner-local coordinates.
func slot_top(slot: WordSlot) -> Vector2:
	var r: Rect2 = _slot_rects.get(slots.find(slot), Rect2())
	return Vector2(r.get_center().x, r.position.y - 2)


func draw(ci: CanvasItem, origin: Vector2, bob: float) -> void:
	for li in lines.size():
		var x := origin.x
		var y := origin.y + li * ComicFont.LINE_HEIGHT
		for seg: Dictionary in lines[li]:
			var w := segment_width(seg)
			if seg.has("text"):
				ComicFont.draw(ci, Vector2(x, y), seg["text"], Palette.INK)
			else:
				var slot: WordSlot = slots[seg["slot"]]
				_slot_rects[seg["slot"]] = Rect2(x - 1, y - 1, w + 1, ComicFont.HEIGHT + 2)
				if slot.word != "":
					var oy := bob if slot.loose else 0.0
					if slot.highlighted:
						Ink.stroke(ci, Ink.round_rect_points(Rect2(x - 2, y - 2 + oy, w + 2, ComicFont.HEIGHT + 4), 2.0), Palette.RED, 0.9, true)
					ComicFont.draw(ci, Vector2(x, y + oy), slot.word, Palette.RED if slot.loose else Palette.INK, true)
				else:
					var c := Palette.RED if slot.highlighted else Palette.PENCIL
					Ink.line(ci, Vector2(x, y + ComicFont.HEIGHT - 0.5), Vector2(x + GAP_WIDTH, y + ComicFont.HEIGHT - 0.5), c, 0.9)
			x += w
