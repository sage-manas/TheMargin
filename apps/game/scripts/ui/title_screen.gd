class_name TitleScreen
extends Control
## Title page: the game's name lettered inside a single panel, with Nib
## standing on the page. The first click or key also unlocks web audio.
## Children, back to front: paper background, title art, menu.

signal chosen(action: String)


var menu: ComicMenu
var has_save := false
var _art: BakedLayer
var _figure: Control
var _chapter := "ch01"
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Palette.PAGE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The paper and lettering never change, so they are baked once.
	_art = BakedLayer.make(_paint, Rect2(0, 0, 640, 360))
	add_child(_art)
	# Nib moves; the lettering doesn't, so only Nib's layer redraws per frame.
	_figure = Control.new()
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_figure)
	_figure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_figure.draw.connect(_paint_nib)
	menu = ComicMenu.new()
	add_child(menu)
	menu.chosen.connect(_on_menu)
	refresh(false)


func refresh(save_exists: bool, chapter := "ch01") -> void:
	has_save = save_exists
	_chapter = chapter
	_art.refresh()
	var items := []
	if has_save:
		items.append({"label": "CONTINUE", "action": "continue"})
	items.append({"label": "NEW GAME", "action": "new"})
	items.append_array(Screens.settings_items())
	menu.index = 0
	menu.set_items(items)
	menu.position = Vector2(roundf(320 - menu.size.x / 2.0), 214)


func _on_menu(action: String) -> void:
	if Screens.handle_setting(action):
		return
	chosen.emit(action)


func _process(delta: float) -> void:
	_time += delta
	_figure.queue_redraw()


func _paint(ci: CanvasItem) -> void:
	Ink.paper_fibres(ci, Rect2(0, 0, 640, 360), 7)
	var panel := Rect2(120, 52, 400, 140)
	ci.draw_rect(Rect2(panel.position + Vector2(4, 5), panel.size), Palette.SHADOW)
	Ink.box(ci, panel, Palette.PAPER, Palette.INK, Ink.W_BORDER)
	ComicFont.draw_centered(ci, 320, 82, "THE MARGIN", Palette.INK, true, 4)
	Ink.line(ci, Vector2(160, 119), Vector2(480, 119), Palette.INK, Ink.W_BORDER)
	ComicFont.draw_centered(ci, 320, 132, "ESCAPE THE DRAWING.", Palette.RED)
	ComicFont.draw(ci, Vector2(128, 178), Chapters.heading(_chapter), Palette.PENCIL)
	ComicFont.draw(ci, Vector2(16, 344), "PLAYTEST BUILD", Palette.PENCIL)


## Nib stands on the title rule, at the edge of the lettering.
func _paint_nib() -> void:
	_figure.draw_set_transform(Vector2(474, 118), 0.0, Vector2(1.6, 1.6))
	Figures.nib(_figure, Vector2.ZERO, -1, "idle", _time * 0.6, fmod(_time, 3.4) > 3.25)
	_figure.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

