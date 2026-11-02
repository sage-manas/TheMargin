class_name TitleScreen
extends Control
## Title page: the game's name lettered inside a single panel, with Nib
## standing on the page. The first click or key also unlocks web audio.
## Children, back to front: paper background, title art, menu.

signal chosen(action: String)

const PAPER := preload("res://shaders/paper.gdshader")

var menu: PixelMenu
var has_save := false
var _art: Control
var _time := 0.0
var _nib: Array[Texture2D] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Palette.PAGE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PAPER
	mat.set_shader_parameter("paper", Palette.PAGE)
	mat.set_shader_parameter("fiber", Palette.PAGE_FIBER)
	bg.material = mat
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.draw.connect(_paint)
	menu = PixelMenu.new()
	add_child(menu)
	menu.chosen.connect(_on_menu)
	_nib = Sprites.frames("nib_idle")
	refresh(false)


func refresh(save_exists: bool) -> void:
	has_save = save_exists
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
	_art.queue_redraw()


func _paint() -> void:
	var ci := _art
	var panel := Rect2(120, 52, 400, 140)
	ci.draw_rect(Rect2(panel.position + Vector2(4, 5), panel.size), Palette.SHADOW)
	Ink.box(ci, panel, Palette.PAPER, Palette.INK, 2)
	PixelFont.draw_centered(ci, 320, 82, "THE MARGIN", Palette.INK, true, 4)
	ci.draw_rect(Rect2(160, 118, 320, 2), Palette.INK)
	PixelFont.draw_centered(ci, 320, 132, "ESCAPE THE DRAWING.", Palette.RED)
	# Nib stands on the title rule, at the edge of the lettering.
	var frame := 1 if fmod(_time, 3.4) > 3.25 else 0
	ci.draw_texture(_nib[frame], Vector2(466, 104))
	PixelFont.draw(ci, Vector2(128, 178), "CHAPTER 1: THE PAGE", Palette.PENCIL)
	PixelFont.draw(ci, Vector2(16, 344), "PROTOTYPE BUILD", Palette.PENCIL)
