class_name PropPainter
extends RefCounted
## Paints decorative props described in page data ({type, at}). Props are
## drawing only — no collision, no behaviour. `at` is the top-left corner.
## Scenery is drawn with thin grey lines and muted colours so it never looks
## like something Nib could use (GDD §9).

const LINE := Ink.W_SCENERY


static func paint(ci: CanvasItem, prop: Dictionary) -> void:
	var at: Array = prop["at"]
	var o := Vector2(at[0], at[1])
	var ln := Palette.SCENERY
	match prop["type"]:
		"bed":
			Ink.box(ci, Rect2(o, Vector2(4, 16)), Palette.muted(Palette.OCHRE), ln, LINE)
			Ink.box(ci, Rect2(o + Vector2(3, 7), Vector2(38, 7)), Palette.muted(Palette.WHITE, 0.2), ln, LINE)
			Ink.box(ci, Rect2(o + Vector2(14, 6), Vector2(27, 8)), Palette.muted(Palette.RED), ln, LINE)
			for x in range(19, 40, 5):
				Ink.line(ci, o + Vector2(x, 7), o + Vector2(x, 13), Palette.muted(Palette.WHITE, 0.2), 0.75)
			Ink.rounded_box(ci, Rect2(o + Vector2(4, 4), Vector2(9, 4)), Palette.muted(Palette.WHITE, 0.2), ln, 2.0, LINE)
			Ink.line(ci, o + Vector2(4.5, 14), o + Vector2(4.5, 16), ln, LINE)
			Ink.line(ci, o + Vector2(39.5, 14), o + Vector2(39.5, 16), ln, LINE)
		"window":
			Ink.box(ci, Rect2(o, Vector2(30, 26)), Palette.muted(Palette.BLUE_LIGHT, 0.25), ln, 1.0)
			Ink.line(ci, o + Vector2(15, 1), o + Vector2(15, 25), ln, 1.0)
			Ink.line(ci, o + Vector2(1, 13), o + Vector2(29, 13), ln, 1.0)
			# A crescent moon: the night outside is drawn too.
			Ink.dot(ci, o + Vector2(22, 6.5), 2.4, Palette.WHITE)
			Ink.dot(ci, o + Vector2(23.4, 5.8), 2.1, Palette.muted(Palette.BLUE_LIGHT, 0.25))
			Ink.line(ci, o + Vector2(-2, 27), o + Vector2(32, 27), ln, 1.2)
		"frame":
			Ink.line(ci, o + Vector2(10, -4), o + Vector2(4, 0), ln, LINE)
			Ink.line(ci, o + Vector2(10, -4), o + Vector2(16, 0), ln, LINE)
			Ink.box(ci, Rect2(o, Vector2(20, 15)), Palette.muted(Palette.WHITE, 0.2), ln, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(3, 12), o + Vector2(9, 5), o + Vector2(12.5, 9), o + Vector2(15, 7), o + Vector2(17, 12)]), Palette.muted(Palette.BLUE))
		"lamp":
			var shade := PackedVector2Array([o + Vector2(2, 10), o + Vector2(5, 0), o + Vector2(11, 0), o + Vector2(14, 10)])
			Ink.shape(ci, shade, Palette.muted(Palette.OCHRE, 0.3), ln, LINE)
			Ink.line(ci, o + Vector2(8, 10), o + Vector2(8, 30), ln, 1.0)
			Ink.line(ci, o + Vector2(3.5, 31), o + Vector2(12.5, 31), ln, 1.5)
		"table":
			Ink.box(ci, Rect2(o, Vector2(30, 3.5)), Palette.muted(Palette.OCHRE), ln, LINE)
			Ink.line(ci, o + Vector2(4, 3.5), o + Vector2(4, 16), ln, 1.0)
			Ink.line(ci, o + Vector2(26, 3.5), o + Vector2(26, 16), ln, 1.0)
			# A cup, with a wisp of steam.
			Ink.box(ci, Rect2(o + Vector2(10, -6), Vector2(6, 6)), Palette.muted(Palette.WHITE, 0.2), ln, LINE)
			Ink.stroke(ci, PackedVector2Array([o + Vector2(16, -4.5), o + Vector2(18, -4), o + Vector2(17.5, -2), o + Vector2(16, -1.5)]), ln, LINE)
			Ink.stroke(ci, PackedVector2Array([o + Vector2(13, -8), o + Vector2(12, -10), o + Vector2(13.5, -12)]), Palette.muted(ln, 0.3), 0.6)
		"rug":
			ci.draw_rect(Rect2(o + Vector2(2, -1), Vector2(40, 2)), Palette.muted(Palette.RED))
			Ink.line(ci, o + Vector2(0, 1), o + Vector2(44, 1), ln, LINE)
		"stool":
			Ink.box(ci, Rect2(o, Vector2(12, 3)), Palette.muted(Palette.OCHRE), ln, LINE)
			Ink.line(ci, o + Vector2(2, 3), o + Vector2(1.5, 10), ln, 1.0)
			Ink.line(ci, o + Vector2(10, 3), o + Vector2(10.5, 10), ln, 1.0)
		"plant":
			for leaf: Array in [[5, 6, -0.9], [8.5, 3, 0.0], [12, 6, 0.9], [6.5, 4, -0.4], [10.5, 4, 0.4]]:
				var c := o + Vector2(leaf[0], leaf[1])
				var pts := Ink.ellipse_points(Vector2.ZERO, Vector2(1.6, 3.6), 12)
				for i in pts.size():
					pts[i] = c + pts[i].rotated(leaf[2])
				Ink.shape(ci, pts, Palette.muted(Palette.LEAF, 0.2), ln, 0.6)
			var pot := PackedVector2Array([o + Vector2(3, 8), o + Vector2(14, 8), o + Vector2(12.5, 16), o + Vector2(4.5, 16)])
			Ink.shape(ci, pot, Palette.muted(Palette.RED), ln, LINE)
		"stairs_sketch":
			# An unfinished staircase climbing UP out of the panel (foreshadowing).
			for i in 8:
				var p := o + Vector2(i * 14, -i * 14)
				Ink.line(ci, p, p + Vector2(14, 0), Palette.PENCIL, 0.75)
				Ink.line(ci, p + Vector2(14, 0), p + Vector2(14, -14), Palette.PENCIL, 0.75)
			Ink.line(ci, o + Vector2(0, 4), o + Vector2(116, -112), Palette.PENCIL, 0.6)
		"ghost_nib":
			# The artist's first sketch of Nib, twice the size, in pencil.
			_scaled(ci, o + Vector2(10, 28), 2.0, func() -> void: Figures.nib(ci, Vector2.ZERO, 1, "idle", 0.0, false, "pencil"))
		"ghost_neighbor":
			# The neighbour as the artist first sketched them; `crossed` when cut.
			_scaled(ci, o + Vector2(12, 40), 2.0, func() -> void: Figures.neighbor(ci, Vector2.ZERO, false, "pencil"))
			if prop.get("crossed", false):
				Ink.line(ci, o + Vector2(-4, -6), o + Vector2(28, 42), Palette.PENCIL, 1.0)
				Ink.line(ci, o + Vector2(28, -6), o + Vector2(-4, 42), Palette.PENCIL, 1.0)
		_:
			push_warning("Unknown prop type: %s" % prop["type"])


## Draws `paint` scaled about `feet` (pencil ghosts are drawn large).
static func _scaled(ci: CanvasItem, feet: Vector2, k: float, paint: Callable) -> void:
	ci.draw_set_transform(feet, 0.0, Vector2(k, k))
	paint.call()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
