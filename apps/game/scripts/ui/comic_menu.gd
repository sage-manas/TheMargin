class_name ComicMenu
extends Control
## Keyboard- and mouse-driven vertical menu, hand-lettered (ComicFont).
## Items: [{label: String | Callable, action: String}].

signal chosen(action: String)

const ROW := 14

var items: Array = []
var index := 0
var active := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_items(list: Array) -> void:
	items = list
	index = clampi(index, 0, maxi(items.size() - 1, 0))
	custom_minimum_size = Vector2(_width(), items.size() * ROW)
	size = custom_minimum_size
	queue_redraw()


func _label(i: int) -> String:
	var l: Variant = items[i]["label"]
	return (l as Callable).call() if l is Callable else str(l)


func _width() -> int:
	var w := 0
	for i in items.size():
		w = maxi(w, ComicFont.measure(_label(i)) + 12)
	return w


func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree() or items.is_empty():
		return
	if event.is_action_pressed("move_up", true) or event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("move_down", true) or event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_accept_game") or event.is_action_pressed("ui_accept"):
		_choose()
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not active or items.is_empty():
		return
	if event is InputEventMouseMotion:
		var i := clampi(int(event.position.y / ROW), 0, items.size() - 1)
		if i != index:
			index = i
			Audio.play("blip")
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		index = clampi(int(event.position.y / ROW), 0, items.size() - 1)
		_choose()
		accept_event()


func _move(d: int) -> void:
	index = wrapi(index + d, 0, items.size())
	Audio.play("blip")
	queue_redraw()


func _choose() -> void:
	Audio.play("tick")
	var action: String = items[index]["action"]
	chosen.emit(action)
	set_items(items)


func _draw() -> void:
	for i in items.size():
		var y := i * ROW + 3
		var selected := i == index
		if selected:
			ComicFont.draw(self, Vector2(0, y), ">", Palette.RED)
		ComicFont.draw(self, Vector2(10, y), _label(i), Palette.RED if selected else Palette.INK, selected)
