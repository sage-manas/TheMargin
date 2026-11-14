class_name ComicFont
extends RefCounted
## Original hand-lettering for captions, bubbles, labels and menus (ADR-0009,
## ADR-0013). Comics are lettered in capitals with a single pen stroke, so each
## glyph is a few strokes on a 7-unit-tall box, drawn as antialiased lines:
## crisp at any size. Bold (emphasis, and loose words) is the same glyph with a
## heavier pen.
##
## The metrics match the old 5×7 bitmap font (cap height 7, about 6 units per
## letter, 9-unit lines), so text laid out for it still fits.

const HEIGHT := 7
const LINE_HEIGHT := 9
const SPACE_ADVANCE := 4
const GAP := 1.6
const PEN := 0.95
const PEN_BOLD := 1.5

## char -> [width, [stroke, ...]]; a stroke is a flat [x0, y0, x1, y1, ...]
## list. A stroke of exactly one point is a dot.
const GLYPHS := {
	"A": [4.4, [[0, 7, 2.2, 0, 4.4, 7], [0.8, 4.7, 3.6, 4.7]]],
	"B": [4.3, [[0, 3.5, 3.1, 3.5, 4.3, 4.5, 4.3, 6, 3.2, 7, 0, 7, 0, 0, 2.8, 0, 3.9, 0.9, 3.9, 2.5, 3.1, 3.5]]],
	"C": [4.3, [[4.3, 1.3, 3.4, 0.1, 1.8, 0, 0.5, 0.9, 0, 2.6, 0, 4.4, 0.5, 6.1, 1.8, 7, 3.4, 6.9, 4.3, 5.7]]],
	"D": [4.4, [[0, 0, 0, 7, 2.2, 7, 3.8, 6, 4.4, 4.3, 4.4, 2.7, 3.8, 1, 2.2, 0, 0, 0]]],
	"E": [4.1, [[4.1, 0, 0, 0, 0, 7, 4.1, 7], [0, 3.5, 3.1, 3.5]]],
	"F": [4.1, [[4.1, 0, 0, 0, 0, 7], [0, 3.5, 3.1, 3.5]]],
	"G": [4.4, [[4.3, 1.3, 3.4, 0.1, 1.8, 0, 0.5, 0.9, 0, 2.6, 0, 4.4, 0.5, 6.1, 1.8, 7, 3.3, 6.9, 4.4, 6, 4.4, 4, 2.4, 4]]],
	"H": [4.4, [[0, 0, 0, 7], [4.4, 0, 4.4, 7], [0, 3.5, 4.4, 3.5]]],
	"I": [3.0, [[0, 0, 3, 0], [1.5, 0, 1.5, 7], [0, 7, 3, 7]]],
	"J": [4.0, [[1.4, 0, 4, 0], [3.2, 0, 3.2, 5.4, 2.6, 6.7, 1.5, 7, 0.4, 6.4, 0, 5.4]]],
	"K": [4.4, [[0, 0, 0, 7], [4.3, 0, 0, 4.4], [1.4, 3, 4.4, 7]]],
	"L": [4.0, [[0, 0, 0, 7, 4, 7]]],
	"M": [5.0, [[0, 7, 0, 0, 2.5, 4.4, 5, 0, 5, 7]]],
	"N": [4.4, [[0, 7, 0, 0, 4.4, 7, 4.4, 0]]],
	"O": [4.6, [[2.3, 0, 3.7, 0.5, 4.5, 2, 4.6, 3.5, 4.5, 5, 3.7, 6.5, 2.3, 7, 0.9, 6.5, 0.1, 5, 0, 3.5, 0.1, 2, 0.9, 0.5, 2.3, 0]]],
	"P": [4.3, [[0, 7, 0, 0, 3, 0, 4.3, 1, 4.3, 2.8, 3, 3.8, 0, 3.8]]],
	"Q": [4.6, [[2.3, 0, 3.7, 0.5, 4.5, 2, 4.6, 3.5, 4.5, 5, 3.7, 6.5, 2.3, 7, 0.9, 6.5, 0.1, 5, 0, 3.5, 0.1, 2, 0.9, 0.5, 2.3, 0], [2.8, 5, 4.7, 7.3]]],
	"R": [4.4, [[0, 7, 0, 0, 3, 0, 4.3, 1, 4.3, 2.8, 3, 3.8, 0, 3.8], [2.2, 3.8, 4.4, 7]]],
	"S": [4.3, [[4.2, 1.1, 3.2, 0.05, 1.4, 0, 0.2, 0.9, 0.2, 2.4, 1.2, 3.3, 3.2, 3.8, 4.3, 4.8, 4.3, 6.1, 3.1, 7, 1.2, 7, 0, 6]]],
	"T": [4.6, [[0, 0, 4.6, 0], [2.3, 0, 2.3, 7]]],
	"U": [4.4, [[0, 0, 0, 5.2, 0.6, 6.6, 2.2, 7, 3.8, 6.6, 4.4, 5.2, 4.4, 0]]],
	"V": [4.4, [[0, 0, 2.2, 7, 4.4, 0]]],
	"W": [5.2, [[0, 0, 1.3, 7, 2.6, 2.4, 3.9, 7, 5.2, 0]]],
	"X": [4.4, [[0, 0, 4.4, 7], [4.4, 0, 0, 7]]],
	"Y": [4.4, [[0, 0, 2.2, 3.6, 4.4, 0], [2.2, 3.6, 2.2, 7]]],
	"Z": [4.4, [[0.2, 0, 4.4, 0, 0, 7, 4.4, 7]]],
	"0": [4.2, [[2.1, 0, 3.5, 0.6, 4.2, 2.2, 4.2, 4.8, 3.5, 6.4, 2.1, 7, 0.7, 6.4, 0, 4.8, 0, 2.2, 0.7, 0.6, 2.1, 0]]],
	"1": [3.4, [[0.4, 1.4, 1.9, 0, 1.9, 7], [0.4, 7, 3.4, 7]]],
	"2": [4.3, [[0.2, 1.4, 1.2, 0.1, 3.1, 0, 4.1, 1, 4.1, 2.4, 0, 7, 4.3, 7]]],
	"3": [4.3, [[0.2, 0.6, 1.4, 0, 3, 0, 4.1, 1, 4.1, 2.4, 2.9, 3.4, 1.6, 3.4], [2.9, 3.4, 4.3, 4.5, 4.3, 6, 3.1, 7, 1.3, 7, 0, 6.3]]],
	"4": [4.4, [[3.2, 7, 3.2, 0, 0, 4.8, 4.4, 4.8]]],
	"5": [4.3, [[4.1, 0, 0.5, 0, 0.2, 3.2, 1.6, 2.8, 3.2, 2.9, 4.3, 4, 4.3, 5.9, 3.2, 7, 1.3, 7, 0, 6.2]]],
	"6": [4.2, [[3.9, 0.4, 2.6, 0, 1.2, 0.4, 0.2, 2, 0, 4.3, 0.3, 6.2, 1.6, 7, 3, 7, 4.2, 6, 4.2, 4.6, 3.1, 3.6, 1.6, 3.6, 0.1, 4.6]]],
	"7": [4.4, [[0, 0, 4.4, 0, 1.6, 7]]],
	"8": [4.4, [[2.2, 3.4, 0.6, 2.7, 0.4, 1.2, 1.3, 0.1, 3.1, 0.1, 4, 1.2, 3.8, 2.7, 2.2, 3.4, 0.4, 4.3, 0, 5.6, 0.9, 6.8, 2.2, 7, 3.5, 6.8, 4.4, 5.6, 4, 4.3, 2.2, 3.4]]],
	"9": [4.2, [[4.1, 2.4, 3, 3.4, 1.4, 3.4, 0.2, 2.4, 0.2, 1, 1.3, 0, 2.9, 0, 4.1, 1, 4.2, 3, 3.9, 5.2, 3, 6.6, 1.6, 7, 0.4, 6.6]]],
	".": [1.0, [[0.5, 6.6]]],
	",": [1.2, [[0.8, 6.1, 0.8, 6.8, 0.2, 7.9]]],
	"!": [1.0, [[0.5, 0, 0.5, 4.8], [0.5, 6.6]]],
	"?": [4.0, [[0.2, 1.2, 1.2, 0.1, 3, 0, 4, 1, 4, 2.2, 2.2, 3.6, 2.2, 4.8], [2.2, 6.6]]],
	"'": [1.0, [[0.5, 0, 0.5, 2]]],
	":": [1.0, [[0.5, 2.2], [0.5, 6.6]]],
	"-": [2.8, [[0.2, 3.6, 2.6, 3.6]]],
	"\"": [2.2, [[0.4, 0, 0.4, 2], [1.8, 0, 1.8, 2]]],
	"(": [1.8, [[1.6, -0.2, 0.4, 1.8, 0, 3.5, 0.4, 5.2, 1.6, 7.2]]],
	")": [1.8, [[0.2, -0.2, 1.4, 1.8, 1.8, 3.5, 1.4, 5.2, 0.2, 7.2]]],
	"/": [4.0, [[4, 0, 0, 7]]],
	"%": [4.4, [[4.2, 0, 0.2, 7], [0.9, 0.4, 1.6, 1.1, 0.9, 1.8, 0.2, 1.1, 0.9, 0.4], [3.5, 5.2, 4.2, 5.9, 3.5, 6.6, 2.8, 5.9, 3.5, 5.2]]],
	"+": [4.0, [[0, 3.5, 4, 3.5], [2, 1.5, 2, 5.5]]],
	"<": [3.0, [[3, 0.5, 0, 3.5, 3, 6.5]]],
	">": [3.0, [[0, 0.5, 3, 3.5, 0, 6.5]]],
	"_": [4.4, [[0, 7, 4.4, 7]]],
}


static func _glyph(c: String) -> Array:
	return GLYPHS.get(c, GLYPHS["?"])


static func glyph_width(c: String, bold := false) -> float:
	if c == " ":
		return SPACE_ADVANCE - GAP
	return float(_glyph(c)[0]) + (0.4 if bold else 0.0)


static func _advance(c: String, bold: bool) -> float:
	return glyph_width(c, bold) + GAP


## Width of one line of text (no trailing gap), rounded up to a whole unit.
static func measure(text: String, bold := false) -> int:
	var w := 0.0
	var upper := text.to_upper()
	for i in upper.length():
		w += _advance(upper[i], bold)
	return maxi(int(ceil(w - GAP)), 0)


## Draws one line of text with its top-left at `pos`. Returns the advance.
static func draw(ci: CanvasItem, pos: Vector2, text: String, color: Color, bold := false, scale := 1.0) -> int:
	var x := 0.0
	var upper := text.to_upper()
	var pen := (PEN_BOLD if bold else PEN) * scale
	for i in upper.length():
		var c := upper[i]
		if c != " ":
			_draw_glyph(ci, pos + Vector2(x, 0), c, color, pen, scale, bold)
		x += _advance(c, bold) * scale
	return int(ceil(x))


static func _draw_glyph(ci: CanvasItem, at: Vector2, c: String, color: Color, pen: float, scale: float, bold: bool) -> void:
	# Bold glyphs are set 0.2 units in so their heavier pen stays on the box.
	var origin := at + Vector2(0.2 if bold else 0.0, 0) * scale
	for s: Array in _glyph(c)[1]:
		if s.size() == 2:
			ci.draw_circle(origin + Vector2(s[0], s[1]) * scale, pen * 0.75, color, true, -1.0, true)
			continue
		var pts := PackedVector2Array()
		for k in range(0, s.size(), 2):
			pts.append(origin + Vector2(s[k], s[k + 1]) * scale)
		ci.draw_polyline(pts, color, pen, true)


## Draws lines separated by "|" or "\n".
static func draw_lines(ci: CanvasItem, pos: Vector2, text: String, color: Color, bold := false, scale := 1.0) -> void:
	var lines := split_lines(text)
	for i in lines.size():
		draw(ci, pos + Vector2(0, i * LINE_HEIGHT * scale), lines[i], color, bold, scale)


static func draw_centered(ci: CanvasItem, center_x: float, y: float, text: String, color: Color, bold := false, scale := 1.0) -> void:
	var w := measure(text, bold) * scale
	draw(ci, Vector2(center_x - w / 2.0, y), text, color, bold, scale)


static func split_lines(text: String) -> PackedStringArray:
	return text.replace("\n", "|").split("|")
