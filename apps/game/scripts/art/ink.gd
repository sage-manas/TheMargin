class_name Ink
extends RefCounted
## Pixel-exact drawing helpers shared by panels, props and UI. Everything is
## drawn with axis-aligned rects so lines never anti-alias.


static func rect_outline(ci: CanvasItem, r: Rect2, color: Color, w := 1) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), color)
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), color)
	ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), color)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), color)


## Filled box with an ink outline.
static func box(ci: CanvasItem, r: Rect2, fill: Color, outline := Palette.INK, w := 1) -> void:
	ci.draw_rect(r, fill)
	rect_outline(ci, r, outline, w)


## Box with its four corner pixels knocked out — reads as a rounded bubble.
static func rounded_box(ci: CanvasItem, r: Rect2, fill: Color, outline := Palette.INK) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	ci.draw_rect(Rect2(x0 + 1, y0 + 1, r.size.x - 2, r.size.y - 2), fill)
	ci.draw_rect(Rect2(x0 + 2, y0, r.size.x - 4, 1), outline)
	ci.draw_rect(Rect2(x0 + 2, y1 - 1, r.size.x - 4, 1), outline)
	ci.draw_rect(Rect2(x0, y0 + 2, 1, r.size.y - 4), outline)
	ci.draw_rect(Rect2(x1 - 1, y0 + 2, 1, r.size.y - 4), outline)
	ci.draw_rect(Rect2(x0 + 1, y0 + 1, 1, 1), outline)
	ci.draw_rect(Rect2(x1 - 2, y0 + 1, 1, 1), outline)
	ci.draw_rect(Rect2(x0 + 1, y1 - 2, 1, 1), outline)
	ci.draw_rect(Rect2(x1 - 2, y1 - 2, 1, 1), outline)


## Dashed horizontal (axis 0) or vertical (axis 1) line from `from` along
## `length` pixels: the "loose ink" look of unlinked openings (GDD §4.1).
static func dashed(ci: CanvasItem, from: Vector2, length: float, axis: int, thickness: float, color: Color, on := 4, off := 3) -> void:
	var t := 0.0
	while t < length:
		var seg := minf(on, length - t)
		if axis == 0:
			ci.draw_rect(Rect2(from + Vector2(t, 0), Vector2(seg, thickness)), color)
		else:
			ci.draw_rect(Rect2(from + Vector2(0, t), Vector2(thickness, seg)), color)
		t += on + off


## 1 px line between integer points (Bresenham) for sketchy pencil lines.
static func line(ci: CanvasItem, a: Vector2i, b: Vector2i, color: Color) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		ci.draw_rect(Rect2(Vector2(p), Vector2.ONE), color)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


## Diagonal hatching inside a rect — the ink shading of solid ground.
static func hatch(ci: CanvasItem, r: Rect2, color: Color, spacing := 4) -> void:
	var w := int(r.size.x)
	var h := int(r.size.y)
	var ox := int(r.position.x)
	var oy := int(r.position.y)
	for k in range(-h, w, spacing):
		var x0 := k
		var y0 := 0
		if x0 < 0:
			y0 = -x0
			x0 = 0
		var steps := mini(w - x0, h - y0)
		for s in steps:
			ci.draw_rect(Rect2(ox + x0 + s, oy + y0 + s, 1, 1), color)
