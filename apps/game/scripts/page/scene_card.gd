class_name SceneCard
extends Node2D
## A loose narrator caption that sets a panel's scene (GDD §4.7): LATER.,
## THAT NIGHT. It sits in a panel's top-right corner, and the reader's hand
## carries it to another panel's corner. A panel holding a card is that
## scene; one without is now, by day.
##
##   page data: cards: [{id, text, scene, panel}]

const H := 12.0
const INSET := 5.0

var card_id := ""
var text := ""
var scene := ""
var panel: ComicPanel
var hovered := false
var selected := false
var dragging := false
## Where it is drawn while carried (page coordinates, top-left).
var drag_pos := Vector2.ZERO
var _time := 0.0


func setup(def: Dictionary, on_panel: ComicPanel) -> void:
	card_id = def["id"]
	text = def["text"]
	scene = def["scene"]
	panel = on_panel
	z_index = 6


func size() -> Vector2:
	return Vector2(ComicFont.measure(text) + 10.0, H)


## The corner slot of `p`, in page coordinates.
static func corner(p: ComicPanel, card_size: Vector2) -> Vector2:
	return p.position + Vector2(p.size.x - card_size.x - INSET, INSET)


func rect() -> Rect2:
	return Rect2(drag_pos if dragging else corner(panel, size()), size())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := rect()
	if dragging:
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(Palette.INK, 0.2))
	var tilt := 0.0 if Settings.reduced_motion or not (hovered or selected) else sin(_time * 3.0) * 0.6
	var edge := Palette.RED if (hovered or selected or dragging) else Palette.INK
	r.position.y += tilt
	Ink.box(self, r, Palette.CAPTION, edge, 1.2 if edge == Palette.RED else 1.0)
	# A dog-ear: the card is loose, it can be picked up.
	var dog := PackedVector2Array([Vector2(r.end.x - 4, r.position.y), r.end - Vector2(0, r.size.y - 4), Vector2(r.end.x - 4, r.position.y + 4)])
	Ink.shape(self, dog, Palette.muted(Palette.CAPTION, -0.15), edge, 0.8)
	ComicFont.draw(self, r.position + Vector2(4, 2.5), text, Palette.INK)
