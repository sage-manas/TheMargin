class_name LabelTag
extends RefCounted
## The label an object obeys (GDD §4.2): a paper tag with its word in bold.
## Every labelled thing uses the same tag, so "a word goes here" reads the
## same on doors, crates, plates and planks. An empty tag has a red dashed
## outline; a loose word is red and bobs; the tag in reach turns red.

const H := 11.0


## Draws the tag for `slot` with its top centre at `top`. Returns its rect.
static func draw(ci: CanvasItem, top: Vector2, slot: WordSlot, min_w := 18.0) -> Rect2:
	var has_word := slot.word != ""
	var w := maxf(ComicFont.measure(slot.word, true) + 8.0, min_w) if has_word else min_w
	var r := Rect2(top - Vector2(w / 2.0, 0), Vector2(w, H))
	if has_word:
		var edge := Palette.RED if slot.highlighted else Palette.INK
		Ink.rounded_box(ci, r, Palette.BUBBLE, edge, 2.0, 1.1 if slot.highlighted else 0.9)
		var bob := 0.0 if (Settings.reduced_motion or not slot.loose) else sin(Time.get_ticks_msec() / 250.0) * 0.6
		ComicFont.draw_centered(ci, r.get_center().x, r.position.y + 2.0 + bob, slot.word, Palette.RED if slot.loose else Palette.INK, true)
	else:
		ci.draw_colored_polygon(Ink.round_rect_points(r, 2.0), Palette.muted(Palette.BUBBLE, 0.3))
		var col := Palette.RED if slot.highlighted else Color(Palette.RED, 0.75)
		var t := 0.8
		Ink.dashed(ci, r.position, r.size.x, 0, t, col, 2.5, 1.5)
		Ink.dashed(ci, Vector2(r.position.x, r.end.y - t), r.size.x, 0, t, col, 2.5, 1.5)
		Ink.dashed(ci, r.position, r.size.y, 1, t, col, 2.5, 1.5)
		Ink.dashed(ci, Vector2(r.end.x - t, r.position.y), r.size.y, 1, t, col, 2.5, 1.5)
		# A blank line where the word goes.
		Ink.line(ci, Vector2(r.position.x + 4, r.end.y - 3), Vector2(r.end.x - 4, r.end.y - 3), Palette.PENCIL, 0.6)
	return r
