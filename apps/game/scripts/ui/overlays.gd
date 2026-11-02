class_name Overlay
extends Control
## A dimmed full-screen card with a title, an optional subtitle and a menu.
## Used for the pause menu and the end card.

signal chosen(action: String)

var title := ""
var subtitle := ""
var menu: PixelMenu
var dim := 0.55
var _card := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	menu = PixelMenu.new()
	add_child(menu)
	menu.chosen.connect(func(a: String) -> void: chosen.emit(a))
	visible = false


func open(items: Array) -> void:
	menu.index = 0
	menu.set_items(items)
	var lines := PixelFont.split_lines(subtitle) if subtitle != "" else PackedStringArray()
	var w := maxi(PixelFont.measure(title, true) * 2, int(menu.size.x))
	for l in lines:
		w = maxi(w, PixelFont.measure(l))
	var h := 40 + lines.size() * PixelFont.LINE_HEIGHT + menu.size.y
	_card = Rect2(roundf(320 - (w + 40) / 2.0), roundf(180 - (h + 16) / 2.0), w + 40, h + 16)
	menu.position = Vector2(roundf(320 - menu.size.x / 2.0), _card.position.y + 34 + lines.size() * PixelFont.LINE_HEIGHT + 4)
	visible = true
	menu.active = true
	queue_redraw()


func close() -> void:
	visible = false
	menu.active = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, dim))
	draw_rect(Rect2(_card.position + Vector2(4, 5), _card.size), Color(0, 0, 0, 0.35))
	Ink.box(self, _card, Palette.PAPER, Palette.INK, 2)
	PixelFont.draw_centered(self, 320, _card.position.y + 10, title, Palette.INK, true, 2)
	var lines := PixelFont.split_lines(subtitle) if subtitle != "" else PackedStringArray()
	for i in lines.size():
		PixelFont.draw_centered(self, 320, _card.position.y + 32 + i * PixelFont.LINE_HEIGHT, lines[i], Palette.PENCIL)
