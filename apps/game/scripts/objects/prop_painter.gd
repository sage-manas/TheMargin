class_name PropPainter
extends RefCounted
## Paints decorative props described in page data ({type, at}). Props are
## drawing only — no collision, no behaviour. `at` is the top-left corner.


static func paint(ci: CanvasItem, prop: Dictionary) -> void:
	var at: Array = prop["at"]
	var o := Vector2(at[0], at[1])
	match prop["type"]:
		"bed":
			Ink.box(ci, Rect2(o + Vector2(0, 0), Vector2(4, 16)), Palette.OCHRE)
			Ink.box(ci, Rect2(o + Vector2(3, 7), Vector2(38, 7)), Palette.WHITE)
			Ink.box(ci, Rect2(o + Vector2(14, 6), Vector2(27, 8)), Palette.RED)
			for x in range(18, 40, 4):
				ci.draw_rect(Rect2(o + Vector2(x, 7), Vector2(1, 6)), Palette.WHITE)
			Ink.box(ci, Rect2(o + Vector2(4, 4), Vector2(9, 4)), Palette.WHITE)
			ci.draw_rect(Rect2(o + Vector2(4, 14), Vector2(1, 2)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(39, 14), Vector2(1, 2)), Palette.INK)
		"window":
			Ink.box(ci, Rect2(o, Vector2(30, 26)), Palette.BLUE_LIGHT, Palette.INK, 2)
			ci.draw_rect(Rect2(o + Vector2(14, 2), Vector2(2, 22)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(2, 12), Vector2(26, 2)), Palette.INK)
			# A crescent moon: the night outside is drawn too.
			ci.draw_rect(Rect2(o + Vector2(20, 4), Vector2(4, 5)), Palette.WHITE)
			ci.draw_rect(Rect2(o + Vector2(22, 4), Vector2(3, 4)), Palette.BLUE_LIGHT)
			ci.draw_rect(Rect2(o + Vector2(-2, 26), Vector2(34, 2)), Palette.INK)
		"frame":
			Ink.box(ci, Rect2(o, Vector2(20, 15)), Palette.WHITE, Palette.INK, 2)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(3, 12), o + Vector2(9, 5), o + Vector2(13, 9), o + Vector2(15, 7), o + Vector2(17, 12)]), Palette.BLUE)
			ci.draw_rect(Rect2(o + Vector2(9, -4), Vector2(2, 4)), Palette.INK)
		"lamp":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(2, 10), o + Vector2(5, 0), o + Vector2(11, 0), o + Vector2(14, 10)]), Palette.OCHRE)
			Ink.line(ci, Vector2i(o + Vector2(2, 10)), Vector2i(o + Vector2(5, 0)), Palette.INK)
			Ink.line(ci, Vector2i(o + Vector2(14, 10)), Vector2i(o + Vector2(11, 0)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(5, 0), Vector2(7, 1)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(2, 10), Vector2(13, 1)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(7, 11), Vector2(2, 19)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(3, 30), Vector2(10, 2)), Palette.INK)
		"table":
			Ink.box(ci, Rect2(o, Vector2(30, 4)), Palette.OCHRE)
			ci.draw_rect(Rect2(o + Vector2(3, 4), Vector2(2, 12)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(25, 4), Vector2(2, 12)), Palette.INK)
			Ink.box(ci, Rect2(o + Vector2(10, -6), Vector2(6, 6)), Palette.WHITE)
			ci.draw_rect(Rect2(o + Vector2(16, -4), Vector2(2, 2)), Palette.INK)
		"rug":
			ci.draw_rect(Rect2(o + Vector2(2, 0), Vector2(40, 2)), Palette.RED)
			ci.draw_rect(Rect2(o, Vector2(44, 1)), Palette.INK)
		"stool":
			Ink.box(ci, Rect2(o, Vector2(12, 3)), Palette.OCHRE)
			ci.draw_rect(Rect2(o + Vector2(1, 3), Vector2(1, 7)), Palette.INK)
			ci.draw_rect(Rect2(o + Vector2(10, 3), Vector2(1, 7)), Palette.INK)
		"plant":
			for leaf: Array in [[2, 4, 4, 2], [8, 0, 3, 6], [11, 5, 4, 2], [5, 2, 3, 5]]:
				Ink.box(ci, Rect2(o + Vector2(leaf[0], leaf[1]), Vector2(leaf[2], leaf[3])), Color("6f8f5c"))
			Ink.box(ci, Rect2(o + Vector2(3, 8), Vector2(11, 8)), Palette.RED)
		"stairs_sketch":
			# An unfinished staircase climbing UP out of the panel (foreshadowing).
			for i in 8:
				var p := Vector2i(o) + Vector2i(i * 14, -i * 14)
				Ink.line(ci, p, p + Vector2i(14, 0), Palette.PENCIL)
				Ink.line(ci, p + Vector2i(14, 0), p + Vector2i(14, -14), Palette.PENCIL)
			Ink.line(ci, Vector2i(o) + Vector2i(0, 4), Vector2i(o) + Vector2i(116, -112), Palette.PENCIL)
		"ghost_nib":
			var tex: Texture2D = Sprites.frames("nib_idle")[0]
			ci.draw_texture_rect(tex, Rect2(o, tex.get_size() * 2), false, Color(Palette.PENCIL, 0.45))
		"ghost_neighbor":
			# The neighbour as the artist first sketched them; `crossed` when cut.
			var tex: Texture2D = Sprites.frames("neighbor")[0]
			var sz := tex.get_size() * 2
			ci.draw_texture_rect(tex, Rect2(o, sz), false, Color(Palette.PENCIL, 0.45))
			if prop.get("crossed", false):
				Ink.line(ci, Vector2i(o) + Vector2i(-4, -2), Vector2i(o + sz) + Vector2i(4, 2), Palette.PENCIL)
				Ink.line(ci, Vector2i(o) + Vector2i(int(sz.x) + 4, -2), Vector2i(o) + Vector2i(-4, int(sz.y) + 2), Palette.PENCIL)
		_:
			push_warning("Unknown prop type: %s" % prop["type"])
