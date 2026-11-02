class_name PanelDrag
extends Node2D
## The reader's hand (GDD §2): moves lifted panels from outside the drawing.
## Mouse: drag a lifted panel. Keyboard: Q selects the next lifted panel,
## direction keys slide it, Q again (or Esc) puts it down.

var page: ComicPage
var dragging: ComicPanel
var selected: ComicPanel
var _hovered: ComicPanel
var _grab := Vector2.ZERO


func panel_mode_active() -> bool:
	return selected != null


func _unhandled_input(event: InputEvent) -> void:
	if page.player.input_locked:
		return
	if event is InputEventMouseMotion:
		_update_hover()
		if dragging:
			_drag_to(get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p := _lifted_at(get_global_mouse_position())
			if p:
				_begin_drag(p)
				get_viewport().set_input_as_handled()
		elif dragging:
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("panel_mode"):
		_cycle_selection()
		get_viewport().set_input_as_handled()
	elif selected:
		if event.is_action_pressed("pause"):
			_select(null)
			get_viewport().set_input_as_handled()
			return
		var dir := Vector2i.ZERO
		if event.is_action_pressed("move_left", true):
			dir = Vector2i.LEFT
		elif event.is_action_pressed("move_right", true):
			dir = Vector2i.RIGHT
		elif event.is_action_pressed("move_up", true):
			dir = Vector2i.UP
		elif event.is_action_pressed("move_down", true):
			dir = Vector2i.DOWN
		if dir != Vector2i.ZERO:
			get_viewport().set_input_as_handled()
			var target := Vector2i(selected.position) + dir * PageConst.GRID
			if page.move_panel_toward(selected, target) == 0:
				_refuse(selected)
			else:
				EventBus.panel_released.emit(selected.panel_id)
				EventBus.state_dirty.emit()


func _lifted_at(point: Vector2) -> ComicPanel:
	for i in range(page.panel_list.size() - 1, -1, -1):
		var p: ComicPanel = page.panel_list[i]
		if p.is_lifted() and Rect2(p.rect()).has_point(point):
			return p
	return null


func _update_hover() -> void:
	var p := _lifted_at(get_global_mouse_position())
	if p == _hovered:
		return
	if _hovered:
		_hovered.hovered = false
	_hovered = p
	if p:
		p.hovered = true
	_set_cursor()


func _set_cursor() -> void:
	if dragging:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	elif _hovered:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _begin_drag(p: ComicPanel) -> void:
	if page.is_player_in_gutter() or p.is_pinned():
		_refuse(p)
		return
	dragging = p
	p.dragging = true
	_grab = get_global_mouse_position() - p.position
	Audio.play("grab")
	_set_cursor()


func _drag_to(mouse: Vector2) -> void:
	var target := Vector2i((mouse - _grab).round())
	var before := Vector2i(dragging.position)
	page.move_panel_toward(dragging, target)
	if Vector2i(dragging.position) == before and page.is_player_in_gutter() and target != before:
		_refuse(dragging)
		_end_drag()


func _end_drag() -> void:
	if dragging == null:
		return
	dragging.dragging = false
	EventBus.panel_released.emit(dragging.panel_id)
	EventBus.state_dirty.emit()
	Audio.play("tick", 0.0, -3.0)
	dragging = null
	_set_cursor()


func _refuse(p: ComicPanel) -> void:
	p.shake()
	Audio.play("deny")


func _cycle_selection() -> void:
	var lifted := page.panel_list.filter(func(p: ComicPanel) -> bool: return p.is_lifted())
	if lifted.is_empty():
		Audio.play("deny")
		return
	var i := lifted.find(selected)
	_select(null if i == lifted.size() - 1 else lifted[i + 1])


func _select(p: ComicPanel) -> void:
	if selected:
		selected.selected = false
	selected = p
	if p:
		p.selected = true
		Audio.play("grab")
	else:
		Audio.play("tick")


func release_all() -> void:
	_end_drag()
	_select(null)
