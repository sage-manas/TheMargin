class_name Ink
extends RefCounted
## The hand-inked drawing kit (ADR-0013). Everything is drawn as antialiased
## vector strokes in page units, so it renders crisp at the window's resolution
## (the page is 640×360 units; on a 1280×720 window one unit is two pixels).
##
## Line weights carry meaning (GDD §9): what can be used is drawn heavy, what is
## only scenery is drawn light, so the eye finds the puzzle first.

## Panel borders.
const W_BORDER := 2.0
## Things Nib can use or that move: crates, doors, plates, platforms, Nib.
const W_THING := 1.5
## Details on those things, lettering.
const W_DETAIL := 1.0
## Scenery: furniture, windows, frames. Thin and grey so it recedes.
const W_SCENERY := 0.75
## Shading strokes.
const W_HATCH := 0.5


## Outline drawn inside `r` (its outer edge on the rect's edge).
static func rect_outline(ci: CanvasItem, r: Rect2, color: Color, w := 1.0) -> void:
	ci.draw_rect(r.grow(-w / 2.0), color, false, w, true)


## Filled box with an ink outline.
static func box(ci: CanvasItem, r: Rect2, fill: Color, outline := Palette.INK, w := 1.0) -> void:
	ci.draw_rect(r, fill)
	rect_outline(ci, r, outline, w)


## Box with rounded corners, the shape of speech bubbles and labels.
static func rounded_box(ci: CanvasItem, r: Rect2, fill: Color, outline := Palette.INK, radius := 3.0, w := 1.0) -> void:
	var pts := round_rect_points(r.grow(-w / 2.0), radius)
	ci.draw_colored_polygon(pts, fill)
	stroke(ci, pts, outline, w, true)


## Points around a rounded rectangle, clockwise from the top-left corner.
static func round_rect_points(r: Rect2, radius: float, steps := 4) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(rad, rad), PI],
		[Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
	]
	for c: Array in corners:
		for i in steps + 1:
			var a: float = c[1] + (PI / 2.0) * i / steps
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


static func ellipse_points(center: Vector2, radii: Vector2, steps := 20, from := 0.0, to := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := from + (to - from) * i / steps
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


## An ink stroke through `pts`; `closed` joins the last point to the first.
static func stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, w := 1.0, closed := false) -> void:
	if pts.size() < 2:
		return
	if closed:
		var c := pts.duplicate()
		c.append(pts[0])
		c.append(pts[1])
		ci.draw_polyline(c, color, w, true)
	else:
		ci.draw_polyline(pts, color, w, true)


## A filled shape with an ink outline.
static func shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline := Palette.INK, w := 1.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	stroke(ci, pts, outline, w, true)


static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, w := 1.0) -> void:
	ci.draw_line(a, b, color, w, true)


static func dot(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_circle(c, r, color, true, -1.0, true)


static func ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, fill: Color, outline := Palette.INK, w := 1.0) -> void:
	shape(ci, ellipse_points(c, radii), fill, outline, w)


## Dashed horizontal (axis 0) or vertical (axis 1) stroke. `from` is the
## top-left of the band the stroke fills, `thickness` its width across.
static func dashed(ci: CanvasItem, from: Vector2, length: float, axis: int, thickness: float, color: Color, on := 4.0, off := 3.0) -> void:
	var t := 0.0
	var dir := Vector2(1, 0) if axis == 0 else Vector2(0, 1)
	var across := Vector2(0, thickness / 2.0) if axis == 0 else Vector2(thickness / 2.0, 0)
	while t < length:
		var seg := minf(on, length - t)
		ci.draw_line(from + across + dir * t, from + across + dir * (t + seg), color, thickness, true)
		t += on + off


## Diagonal shading strokes clipped to `r`, like pen hatching.
static func hatch(ci: CanvasItem, r: Rect2, color: Color, spacing := 4.0, w := W_HATCH) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var k := -r.size.y
	while k < r.size.x:
		# The line x = k + t, y = t for t in [0, h], clipped to 0 <= x <= w.
		var t0 := maxf(0.0, -k)
		var t1 := minf(r.size.y, r.size.x - k)
		if t1 > t0:
			ci.draw_line(r.position + Vector2(k + t0, t0), r.position + Vector2(k + t1, t1), color, w, true)
		k += spacing


## A small filled arrowhead pointing along `dir`, tip at `tip`.
static func arrowhead(ci: CanvasItem, tip: Vector2, dir: Vector2, length: float, color: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var base := tip - d * length
	ci.draw_colored_polygon(PackedVector2Array([tip, base + n * length * 0.6, base - n * length * 0.6]), color)


## The page's paper fibres: short faint strands and specks scattered over
## `r`, the same every time for the same `seed`. Drawn once into a static
## layer, so the page has texture without a per-pixel shader (ADR-0013).
static func paper_fibres(ci: CanvasItem, r: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(r.size.x * r.size.y / 900.0)
	for i in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		if i % 3 == 0:
			ci.draw_circle(p, rng.randf_range(0.25, 0.5), Palette.PAGE_FIBER, true, -1.0, true)
		else:
			var d := Vector2.from_angle(rng.randf_range(-0.35, 0.35)) * rng.randf_range(3.0, 8.0)
			ci.draw_line(p, p + d, Color(Palette.PAGE_FIBER, 0.7), 0.4, true)

