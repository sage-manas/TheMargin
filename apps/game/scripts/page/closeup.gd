class_name CloseUp
extends Node2D
## A close-up (GDD §4.8): a round inset panel that magnifies one spot of the
## page. Whatever control is under its focus ring is drawn big inside it,
## and the reader works it there. The close-up looks at the page, not at a
## thing: slide a panel and it sees what is now under the ring.
##
##   page data: closeups: [{id, at: [x, y], r, focus: [x, y]}]

const FOCUS_R := 10.0

var closeup_id := ""
var center := Vector2.ZERO
var radius := 28.0
var focus := Vector2.ZERO
var page: ComicPage
var hovered := false
var selected := false
## The part under the hand or keyboard: 0 for a lever, a wheel for a dial.
var hot := -1


func setup(def: Dictionary, owner_page: ComicPage) -> void:
	closeup_id = def["id"]
	var a: Array = def["at"]
	center = Vector2(a[0], a[1])
	radius = float(def.get("r", 28.0))
	var f: Array = def["focus"]
	focus = Vector2(f[0], f[1])
	page = owner_page
	z_index = 5


## The control under the focus ring, if any (one in a panel Nib can see).
func control() -> PageControl:
	for c: PageControl in page.controls.values():
		if c.is_visible_in_tree() and c.global_position.distance_to(focus) <= FOCUS_R:
			return c
	return null


func contains(p: Vector2) -> bool:
	return p.distance_to(center) <= radius


## The reader clicks at page point `p`. Returns whether anything happened.
func click(p: Vector2) -> bool:
	var c := control()
	if c == null:
		return false
	var h: Variant = c.hit(p - center, radius)
	if h == null:
		return false
	if c.kind == "lever":
		c.pull()
	else:
		c.turn(h[0], h[1])
	return true


func hover(p: Variant) -> void:
	var c := control()
	var h: Variant = c.hit(p - center, radius) if c and p is Vector2 else null
	hot = h[0] if h != null else -1
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := control()
	var edge := Palette.RED if (hovered or selected) else Palette.INK
	# The zoom cone: two pencil lines from the ring on the page to the inset.
	var d := (center - focus)
	if d.length() > radius + FOCUS_R:
		var n := Vector2(-d.y, d.x).normalized()
		for s in [-1.0, 1.0]:
			Ink.line(self, focus + n * s * FOCUS_R, center + n * s * radius, Color(Palette.PENCIL, 0.8), 0.6)
	Ink.stroke(self, Ink.ellipse_points(focus, Vector2(FOCUS_R, FOCUS_R), 24), edge if c else Palette.PENCIL, 0.9, true)
	# The inset itself.
	draw_circle(center + Vector2(2.5, 3), radius, Color(Palette.SHADOW, 0.85), true, -1.0, true)
	draw_circle(center, radius, Palette.PAPER, true, -1.0, true)
	if c:
		draw_set_transform(center, 0.0, Vector2.ONE)
		c.draw_closeup(self, radius, hot)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Nothing to see: the ring is over empty page.
		Ink.hatch(self, Rect2(center - Vector2(radius, radius) * 0.5, Vector2(radius, radius)), Color(Palette.SHADOW, 0.6), 4.0)
	Ink.stroke(self, Ink.ellipse_points(center, Vector2(radius, radius), 40), edge, Ink.W_BORDER, true)
