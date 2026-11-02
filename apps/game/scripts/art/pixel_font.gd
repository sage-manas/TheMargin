class_name PixelFont
extends RefCounted
## Original 5x7 uppercase comic-lettering font (ADR-0009).
## Glyphs are baked once into a white atlas and tinted at draw time, so each
## character costs a single draw call. Bold is the regular glyph doubled 1 px
## to the right — the classic pixel-font emboldening.

const HEIGHT := 7
const LINE_HEIGHT := 9
const SPACE_ADVANCE := 4

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	".": [".", ".", ".", ".", ".", ".", "#"],
	",": ["..", "..", "..", "..", "..", ".#", "#."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"'": ["#", "#", ".", ".", ".", ".", "."],
	":": [".", "#", ".", ".", ".", "#", "."],
	"-": ["...", "...", "...", "###", "...", "...", "..."],
	"\"": ["#.#", "#.#", "...", "...", "...", "...", "..."],
	"(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
	"/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
	"%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
	">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
}

static var _atlas: ImageTexture
static var _regions := {}   # char -> Rect2i of the regular glyph; bold is +1 width at y+8


static func _ensure_atlas() -> void:
	if _atlas != null:
		return
	var total_w := 0
	for key in GLYPHS:
		total_w += (GLYPHS[key][0] as String).length() + 2
	var img := Image.create(total_w, HEIGHT * 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x := 0
	for key in GLYPHS:
		var rows: Array = GLYPHS[key]
		var w := (rows[0] as String).length()
		for gy in HEIGHT:
			var row: String = rows[gy]
			for gx in w:
				if row[gx] == "#":
					img.set_pixel(x + gx, gy, Color.WHITE)
					img.set_pixel(x + gx, HEIGHT + 1 + gy, Color.WHITE)
					img.set_pixel(x + gx + 1, HEIGHT + 1 + gy, Color.WHITE)
		_regions[key] = Rect2i(x, 0, w, HEIGHT)
		x += w + 2
	_atlas = ImageTexture.create_from_image(img)


static func glyph_width(c: String, bold := false) -> int:
	if c == " ":
		return SPACE_ADVANCE - 1
	var rows: Array = GLYPHS.get(c, GLYPHS["?"])
	return (rows[0] as String).length() + (1 if bold else 0)


## Width in pixels of a single line of text (no trailing spacing).
static func measure(text: String, bold := false) -> int:
	var w := 0
	var upper := text.to_upper()
	for i in upper.length():
		w += glyph_width(upper[i], bold) + 1
	return maxi(w - 1, 0)


## Draws one line of text with its top-left at pos. Returns the advance width.
static func draw(ci: CanvasItem, pos: Vector2, text: String, color: Color, bold := false, scale := 1) -> int:
	_ensure_atlas()
	var x := 0
	var upper := text.to_upper()
	for i in upper.length():
		var c := upper[i]
		if c == " ":
			x += SPACE_ADVANCE * scale
			continue
		var key: String = c if _regions.has(c) else "?"
		var src: Rect2i = _regions[key]
		if bold:
			src = Rect2i(src.position.x, HEIGHT + 1, src.size.x + 1, HEIGHT)
		var dst := Rect2(pos + Vector2(x, 0), Vector2(src.size) * scale)
		ci.draw_texture_rect_region(_atlas, dst, Rect2(src), color)
		x += (src.size.x + 1) * scale
	return x


## Draws multiple lines separated by "|" or "\n".
static func draw_lines(ci: CanvasItem, pos: Vector2, text: String, color: Color, bold := false, scale := 1) -> void:
	var lines := split_lines(text)
	for i in lines.size():
		draw(ci, pos + Vector2(0, i * LINE_HEIGHT * scale), lines[i], color, bold, scale)


static func draw_centered(ci: CanvasItem, center_x: float, y: float, text: String, color: Color, bold := false, scale := 1) -> void:
	var w := measure(text, bold) * scale
	draw(ci, Vector2(roundf(center_x - w / 2.0), y), text, color, bold, scale)


static func split_lines(text: String) -> PackedStringArray:
	return text.replace("\n", "|").split("|")
