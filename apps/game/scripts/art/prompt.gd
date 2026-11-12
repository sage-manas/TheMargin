class_name Prompt
extends RefCounted
## The "press a key" prompt above Nib: a keycap and what it will do. One
## drawer for every prompt so they all look alike (GDD §9). A prompt that
## can't act (a refusal) has no keycap and grey lettering.


## Draws a prompt with its top centre at `top`. Returns its rect.
static func draw(ci: CanvasItem, top: Vector2, key: String, text: String, acting := true) -> Rect2:
	var key_w := ComicFont.measure(key) + 5.0 if acting else 0.0
	var w := ComicFont.measure(text) + 8.0 + (key_w + 3.0 if acting else 0.0)
	var r := Rect2(top.x - w / 2.0, top.y, w, 12)
	Ink.rounded_box(ci, r, Palette.WHITE, Palette.INK if acting else Palette.PENCIL, 3.0, 0.9)
	var x := r.position.x + 3.0
	if acting:
		var cap := Rect2(x, r.position.y + 1.8, key_w, 8.4)
		Ink.rounded_box(ci, cap, Palette.INK, Palette.INK, 1.5, 0.6)
		ComicFont.draw(ci, cap.position + Vector2(2.5, 0.7), key, Palette.WHITE)
		x += key_w + 3.0
	ComicFont.draw(ci, Vector2(x + 1.0, r.position.y + 2.5), text, Palette.INK if acting else Palette.PENCIL)
	return r
