class_name Figures
extends RefCounted
## The characters, drawn as ink figures (ADR-0013). Coordinates are local to
## the figure's feet (bottom centre); Nib faces right when `facing` is 1.
## `style` "ink" is the character as drawn; "pencil" is the artist's ghost
## sketch of it (grey, unfilled).


## Nib: a pen-nib cap, a round face, a red scarf, two legs.
## `pose` is "idle", "walk" or "air"; `phase` drives the walk cycle and the
## scarf; `blink` closes the eyes.
static func nib(ci: CanvasItem, feet: Vector2, facing := 1, pose := "idle", phase := 0.0, blink := false, style := "ink") -> void:
	var ink := Palette.INK if style == "ink" else Palette.PENCIL
	var fill := Palette.WHITE if style == "ink" else Color(Palette.PAGE, 0.0)
	var f := float(signi(facing)) if facing != 0 else 1.0
	var at := func(x: float, y: float) -> Vector2: return feet + Vector2(x * f, y)

	# Legs: a stride while walking, tucked in the air.
	var swing := sin(phase * TAU) * 1.8 if pose == "walk" else 0.0
	var lift := 1.2 if pose == "air" else 0.0
	for side in [-1.0, 1.0]:
		var hip: Vector2 = at.call(side * 1.6, -3.6)
		var foot: Vector2 = at.call(side * 1.6 + swing * side, -lift * (1.0 if side > 0 else 0.4))
		Ink.line(ci, hip, foot, ink, 1.2)
		Ink.line(ci, foot, foot + Vector2(f * 1.2, 0), ink, 1.2)

	# Scarf tail, streaming behind, longer and livelier on the move.
	var flutter := sin(phase * TAU * 2.0) * (0.9 if pose != "idle" else 0.35)
	var reach := 6.5 if pose != "idle" else 4.5
	if style == "ink":
		var tail := PackedVector2Array([at.call(-2.8, -5.4), at.call(-reach, -4.6 + flutter), at.call(-reach + 0.8, -3.1 + flutter), at.call(-2.8, -3.9)])
		Ink.shape(ci, tail, Palette.RED, ink, 0.8)

	# Head and body: one rounded bean.
	var body := Ink.round_rect_points(Rect2(feet + Vector2(-4.2, -12.6), Vector2(8.4, 9.4)), 3.6)
	Ink.shape(ci, body, fill, ink, 1.3)

	# Scarf band.
	if style == "ink":
		var band := Rect2(feet + Vector2(-4.3, -5.6), Vector2(8.6, 1.9))
		ci.draw_rect(band, Palette.RED)
		Ink.line(ci, band.position, band.position + Vector2(band.size.x, 0), ink, 0.6)
		Ink.line(ci, band.position + Vector2(0, band.size.y), band.end, ink, 0.6)

	# The pen-nib cap, with its slit.
	var cap := PackedVector2Array([at.call(0.0, -16.6), at.call(-2.5, -12.2), at.call(2.5, -12.2)])
	if style == "ink":
		ci.draw_colored_polygon(cap, ink)
		Ink.line(ci, at.call(0.0, -15.4), at.call(0.0, -13.0), Palette.WHITE, 0.5)
		Ink.dot(ci, at.call(0.0, -12.9), 0.45, Palette.WHITE)
	else:
		Ink.stroke(ci, cap, ink, 0.8, true)

	# Eyes, looking where Nib faces.
	for ex in [0.5, 2.6]:
		var e: Vector2 = at.call(ex, -8.6)
		if blink:
			Ink.line(ci, e - Vector2(0.7, 0), e + Vector2(0.7, 0), ink, 0.7)
		else:
			ci.draw_colored_polygon(Ink.ellipse_points(e, Vector2(0.55, 1.05), 10), ink)


## The neighbour from next door: a hat, a long blue coat, a worried face.
static func neighbor(ci: CanvasItem, feet: Vector2, blink := false, style := "ink") -> void:
	var ink := Palette.INK if style == "ink" else Palette.PENCIL
	var coat := Palette.BLUE if style == "ink" else Color(Palette.PAGE, 0.0)
	var face := Palette.WHITE if style == "ink" else Color(Palette.PAGE, 0.0)
	var p := func(x: float, y: float) -> Vector2: return feet + Vector2(x, y)
	# Legs.
	for x in [-2.2, 2.2]:
		Ink.line(ci, p.call(x, -4.5), p.call(x, 0), ink, 1.2)
		Ink.line(ci, p.call(x, 0), p.call(x - 1.6, 0), ink, 1.3)
	# Coat: a trapezoid with buttons.
	var body := PackedVector2Array([p.call(-3.6, -12.5), p.call(3.6, -12.5), p.call(5.2, -4.2), p.call(-5.2, -4.2)])
	Ink.shape(ci, body, coat, ink, 1.3)
	if style == "ink":
		for y in [-10.2, -7.4]:
			Ink.dot(ci, p.call(0, y), 0.6, Palette.OCHRE)
	# Head.
	Ink.shape(ci, Ink.round_rect_points(Rect2(feet + Vector2(-3.1, -18.6), Vector2(6.2, 6.4)), 2.4), face, ink, 1.2)
	for ex in [-1.2, 1.2]:
		var e: Vector2 = p.call(ex, -15.3)
		if blink:
			Ink.line(ci, e - Vector2(0.6, 0), e + Vector2(0.6, 0), ink, 0.6)
		else:
			Ink.dot(ci, e, 0.6, ink)
	# A worried mouth.
	Ink.stroke(ci, PackedVector2Array([p.call(-1.2, -13.4), p.call(0, -13.9), p.call(1.2, -13.4)]), ink, 0.6)
	# Hat: brim and crown.
	if style == "ink":
		ci.draw_rect(Rect2(feet + Vector2(-2.8, -22.6), Vector2(5.6, 4.2)), ink)
	else:
		Ink.rect_outline(ci, Rect2(feet + Vector2(-2.8, -22.6), Vector2(5.6, 4.2)), ink, 0.8)
	Ink.line(ci, p.call(-4.6, -18.4), p.call(4.6, -18.4), ink, 1.3)


## Height above the feet of each figure's top, for placing thoughts and tags.
const NIB_HEIGHT := 17.0
const NEIGHBOR_HEIGHT := 23.0
