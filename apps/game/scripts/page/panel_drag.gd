class_name PanelDrag
extends Node2D
## The reader's hand (GDD §2): works the page from outside the drawing.
##   Lifted panels: drag to slide (GDD §4.1).
##   Scene cards: drag to another panel's corner (GDD §4.7).
##   Close-ups: click the control inside (GDD §4.8).
## Keyboard (panel mode): Q selects the next thing the hand can work (lifted
## panels, then cards, then close-ups); direction keys slide a panel, hop a
## card to the next panel that way, or pick and turn a close-up's control
## (E pulls a lever); Q again (or Esc) puts it down.

var page: ComicPage
var dragging: ComicPanel
## The selection in panel mode: a ComicPanel, SceneCard or CloseUp.
var selected: Node
var _hovered: Node
var _grab := Vector2.ZERO
var _card: SceneCard


func panel_mode_active() -> bool:
	return selected != null


func _unhandled_input(event: InputEvent) -> void:
	if page.player.input_locked:
		return
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		_update_hover(m)
		if dragging:
			_drag_to(m)
		elif _card:
			_card.drag_pos = m - _grab
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed:
			var thing := _thing_at(m)
			if thing is CloseUp:
				if not (thing as CloseUp).click(m):
					Audio.play("deny", 0.0, -8.0)
				get_viewport().set_input_as_handled()
			elif thing is SceneCard:
				_begin_card(thing)
				get_viewport().set_input_as_handled()
			elif thing is ComicPanel:
				_begin_drag(thing)
				get_viewport().set_input_as_handled()
		elif dragging:
			_end_drag()
			get_viewport().set_input_as_handled()
		elif _card:
			_drop_card(m)
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
		if selected is CloseUp and event.is_action_pressed("interact"):
			_work_closeup(selected as CloseUp, Vector2i.ZERO, true)
			get_viewport().set_input_as_handled()
			return
		if dir == Vector2i.ZERO:
			return
		get_viewport().set_input_as_handled()
		if selected is ComicPanel:
			var p: ComicPanel = selected
			var target := Vector2i(p.position) + dir * PageConst.GRID
			if page.move_panel_toward(p, target) == 0:
				_refuse(p)
			else:
				EventBus.panel_released.emit(p.panel_id)
				EventBus.state_dirty.emit()
		elif selected is SceneCard:
			var card: SceneCard = selected
			var next := _panel_toward(card.panel, Vector2(dir))
			if next == null or not page.move_card(card, next):
				_refuse(next if next else card.panel)
		elif selected is CloseUp:
			_work_closeup(selected as CloseUp, dir, false)


# --- what the hand can work -----------------------------------------------------

func _lifted_at(point: Vector2) -> ComicPanel:
	for i in range(page.panel_list.size() - 1, -1, -1):
		var p: ComicPanel = page.panel_list[i]
		if p.is_lifted() and Rect2(p.rect()).has_point(point):
			return p
	return null


## The topmost thing under `point`: a close-up, then a card, then a lifted panel.
func _thing_at(point: Vector2) -> Node:
	for c: CloseUp in page.closeups.values():
		if c.contains(point):
			return c
	for card: SceneCard in page.cards.values():
		if card.rect().has_point(point):
			return card
	return _lifted_at(point)


## The inked panel whose rect contains `point`, for dropping a card.
func _panel_at(point: Vector2) -> ComicPanel:
	for i in range(page.panel_list.size() - 1, -1, -1):
		var p: ComicPanel = page.panel_list[i]
		if Rect2(p.rect()).has_point(point) and page.can_hold_card(p):
			return p
	return null


## The nearest card-holding panel from `p` in direction `d` (by centres).
func _panel_toward(p: ComicPanel, d: Vector2) -> ComicPanel:
	var from := Rect2(p.rect()).get_center()
	var best: ComicPanel = null
	var best_score := INF
	for q in page.panel_list:
		if q == p or not page.can_hold_card(q):
			continue
		var v := Rect2(q.rect()).get_center() - from
		var along := v.dot(d)
		if along <= 0.0:
			continue
		var score := along + absf(v.dot(Vector2(-d.y, d.x))) * 2.0
		if score < best_score:
			best_score = score
			best = q
	return best


func _update_hover(m: Vector2) -> void:
	var thing := _thing_at(m)
	for c: CloseUp in page.closeups.values():
		c.hover(m if c == thing else null)
	if thing == _hovered:
		_set_cursor()
		return
	if _hovered:
		_hovered.set("hovered", false)
	_hovered = thing
	if thing:
		thing.set("hovered", true)
	_set_cursor()


func _set_cursor() -> void:
	if dragging or _card:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	elif _hovered:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# --- panels ------------------------------------------------------------------

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


# --- scene cards ---------------------------------------------------------------

func _begin_card(card: SceneCard) -> void:
	_card = card
	_grab = get_global_mouse_position() - card.rect().position
	card.drag_pos = card.rect().position
	card.dragging = true
	Audio.play("grab")
	_set_cursor()


## Drops the carried card on the panel under the hand, or back where it was.
func _drop_card(m: Vector2) -> void:
	var card := _card
	_card = null
	card.dragging = false
	var target := _panel_at(m)
	if target and target != card.panel and not page.move_card(card, target):
		_refuse(target)
	elif target == null or target == card.panel:
		Audio.play("tick", 0.0, -3.0)
	_set_cursor()


# --- close-ups ------------------------------------------------------------------

## Keyboard work on a close-up: left/right picks a dial wheel, up/down turns
## it; E (or up/down) pulls a lever.
func _work_closeup(c: CloseUp, dir: Vector2i, pull: bool) -> void:
	var ctl := c.control()
	if ctl == null:
		Audio.play("deny")
		return
	if ctl.kind == "lever":
		if pull or dir.y != 0:
			ctl.pull()
		c.hot = 0
	else:
		c.hot = clampi(c.hot if c.hot >= 0 else 0, 0, ctl.digits.size() - 1)
		if dir.x != 0:
			c.hot = clampi(c.hot + dir.x, 0, ctl.digits.size() - 1)
			Audio.play("blip")
		elif dir.y != 0:
			ctl.turn(c.hot, -dir.y)
	c.queue_redraw()


func _refuse(p: ComicPanel) -> void:
	if p:
		p.shake()
	Audio.play("deny")


# --- panel mode -----------------------------------------------------------------

func _cycle_selection() -> void:
	var things: Array = page.panel_list.filter(func(p: ComicPanel) -> bool: return p.is_lifted())
	things.append_array(page.cards.values())
	things.append_array(page.closeups.values())
	if things.is_empty():
		Audio.play("deny")
		return
	var i := things.find(selected)
	_select(null if i == things.size() - 1 else things[i + 1])


func _select(thing: Node) -> void:
	if selected:
		selected.set("selected", false)
		if selected is CloseUp:
			(selected as CloseUp).hot = -1
	selected = thing
	if thing:
		thing.set("selected", true)
		Audio.play("grab")
	else:
		Audio.play("tick")


func release_all() -> void:
	_end_drag()
	if _card:
		_card.dragging = false
		_card = null
	_select(null)
