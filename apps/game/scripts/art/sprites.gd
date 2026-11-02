class_name Sprites
extends RefCounted
## Sprites authored as text grids (ADR-0009). One character = one pixel,
## colours from Palette.SPRITE_MAP, "." is transparent. Nib faces right.

const DATA := {
	"nib_idle": [
		[
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWKWKWK.",
			".KWWWWWWK.",
			"..KKKKKK..",
			".RRRRRRRR.",
			"RRKWWWWK..",
			"..KWWWWK..",
			"..KKKKKK..",
			"..K....K..",
			".KK....KK.",
		],
		[
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWWWWWK.",
			".KWWKKKWK.",
			"..KKKKKK..",
			".RRRRRRRR.",
			".RKWWWWK..",
			"R.KWWWWK..",
			"..KKKKKK..",
			"..K....K..",
			".KK....KK.",
		],
	],
	"nib_walk": [
		[
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWKWKWK.",
			".KWWWWWWK.",
			"..KKKKKK..",
			".RRRRRRRR.",
			"RRKWWWWK..",
			"..KWWWWK..",
			"..KKKKKK..",
			"..K....K..",
			".KK....KK.",
		],
		[
			"..........",
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWKWKWK.",
			".KWWWWWWK.",
			"..KKKKKK..",
			"RRRRRRRRR.",
			"..KWWWWK..",
			"..KKKKKK..",
			"...K..K...",
			"..KK.KK...",
		],
		[
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWKWKWK.",
			".KWWWWWWK.",
			"..KKKKKK..",
			".RRRRRRRR.",
			"R.KWWWWK..",
			"R.KWWWWK..",
			"..KKKKKK..",
			".K......K.",
			"KK.......K",
		],
		[
			"..........",
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWKWKWK.",
			".KWWWWWWK.",
			"..KKKKKK..",
			"RRRRRRRRR.",
			"..KWWWWK..",
			"..KKKKKK..",
			"...K..K...",
			"...KK.KK..",
		],
	],
	"nib_air": [
		[
			"....KK....",
			"...KKKK...",
			"...KWKK...",
			"..KKKKKK..",
			".KWWWWWWK.",
			".KWWKWKWK.",
			".KWWWWWWK.",
			"R.KKKKKK..",
			".RRRRRRRR.",
			"..KWWWWK..",
			"..KWWWWK..",
			"..KKKKKK..",
			"..KK..KK..",
			"..........",
		],
	],
	"neighbor": [
		[
			"...KKKKKK...",
			"...KKKKKK...",
			".KKKKKKKKKK.",
			"...KWWWWK...",
			"...KWKWWK...",
			"...KWWWWK...",
			"...KKKWWK...",
			"....KWWK....",
			"..KKKKKKKK..",
			".KBBBBBBBBK.",
			".KBBBBYBBBK.",
			".KBBBBBBBBK.",
			".KBBBBYBBBK.",
			".KBBBBBBBBK.",
			".KBBBBBBBBK.",
			"..KBBBBBBK..",
			"..KBBKKBBK..",
			"..KBK..KBK..",
			"..KBK..KBK..",
			".KKK..KKK...",
		],
		[
			"...KKKKKK...",
			"...KKKKKK...",
			".KKKKKKKKKK.",
			"...KWWWWK...",
			"...KKKWWK...",
			"...KWWWWK...",
			"...KKKWWK...",
			"....KWWK....",
			"..KKKKKKKK..",
			".KBBBBBBBBK.",
			".KBBBBYBBBK.",
			".KBBBBBBBBK.",
			".KBBBBYBBBK.",
			".KBBBBBBBBK.",
			".KBBBBBBBBK.",
			"..KBBBBBBK..",
			"..KBBKKBBK..",
			"..KBK..KBK..",
			"..KBK..KBK..",
			".KKK..KKK...",
		],
	],
}

static var _cache := {}


static func frames(name: String) -> Array[Texture2D]:
	if _cache.has(name):
		return _cache[name]
	var out: Array[Texture2D] = []
	for grid in DATA[name]:
		out.append(_bake(grid))
	_cache[name] = out
	return out


static func _bake(grid: Array) -> Texture2D:
	var h := grid.size()
	var w := (grid[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = grid[y]
		for x in w:
			var c := row[x]
			if Palette.SPRITE_MAP.has(c):
				img.set_pixel(x, y, Palette.SPRITE_MAP[c])
	return ImageTexture.create_from_image(img)
