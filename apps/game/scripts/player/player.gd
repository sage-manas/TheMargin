class_name Player
extends CharacterBody2D
## Nib. Walk + short hop with coyote time and jump buffering (GDD §3).
## Origin is at the feet. Panel moves translate the player explicitly
## (ComicPage.move_panel_toward), so there is no platform velocity here.

const SIZE := Vector2(8, 13)
const WALK_SPEED := 70.0
const ACCEL := 700.0
const DECEL := 1000.0
const AIR_ACCEL := 520.0
const GRAVITY := 900.0
const JUMP_VELOCITY := 232.0
const JUMP_CUT := 0.45
const MAX_FALL := 330.0
const COYOTE := 0.1
const BUFFER := 0.12
## Nib's own collision layer. Nib collides with the world (layer 1), but
## world bodies that move themselves (crates) don't collide with Nib and
## resolve Nib explicitly instead.
const LAYER := 2
## How close a crate or platform lifts Nib's head to a ceiling. Touching it
## would wedge Nib's body between ceiling and carrier, unable to walk off.
const HEADROOM := 1.0

var page: ComicPage
var facing := 1
## Mirrors PlayerInteraction.carrying for the floating word tag.
var carrying := ""
var input_locked := false

var _figure: DrawLayer
var _tag: DrawLayer
var _pose := "idle"
var _phase := 0.0
var _blink_t := 2.5
var _coyote := 0.0
var _buffer := 0.0
var _jump_held := false
var _step_t := 0.0
var _was_on_floor := true
var _time := 0.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1
	# Whatever carries Nib (a panel, crate or platform) moves Nib itself, so
	# no floor may add its own velocity on top.
	platform_floor_layers = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	cs.shape = shape
	cs.position = Vector2(0, -SIZE.y / 2.0)
	add_child(cs)
	_figure = DrawLayer.make(_draw_figure)
	add_child(_figure)
	_tag = DrawLayer.make(_draw_tag, 5)
	add_child(_tag)
	floor_snap_length = 3.0
	z_index = 3


func collision_rect() -> Rect2:
	return Rect2(global_position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func can_act() -> bool:
	return not input_locked and not (page and page.drag.panel_mode_active())


func _physics_process(delta: float) -> void:
	_time += delta
	var dir := 0.0
	var act := can_act()
	if act:
		dir = Input.get_axis("move_left", "move_right")

	if is_on_floor():
		_coyote = COYOTE
		_jump_held = false
	else:
		_coyote -= delta
	if act and Input.is_action_just_pressed("jump"):
		_buffer = BUFFER
	else:
		_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_jump_held = true
		Audio.play("hop")
	if _jump_held and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT
		_jump_held = false

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var rate := (ACCEL if dir != 0.0 else DECEL) if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, dir * WALK_SPEED, rate * delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1

	var fall_speed := velocity.y
	move_and_slide()

	if is_on_floor() and not _was_on_floor and fall_speed > 140.0:
		Audio.play("land")
	_was_on_floor = is_on_floor()
	if is_on_floor() and absf(velocity.x) > 20.0:
		_step_t -= delta
		if _step_t <= 0.0:
			Audio.play("step", 0.15)
			_step_t = 0.26
	else:
		_step_t = 0.0
	_animate(delta)


func _animate(delta: float) -> void:
	_pose = "idle"
	if not is_on_floor():
		_pose = "air"
	elif absf(velocity.x) > 10.0:
		_pose = "walk"
	# One stride cycle per 0.4 s at full speed; the scarf keeps moving at rest.
	_phase += delta * (absf(velocity.x) / WALK_SPEED * 2.5 if _pose == "walk" else 0.6)
	_blink_t -= delta
	if _blink_t < -0.15:
		_blink_t = randf_range(2.0, 4.0)
	_figure.queue_redraw()
	_tag.queue_redraw()


func _draw_figure(ci: CanvasItem) -> void:
	Figures.nib(ci, Vector2.ZERO, facing, _pose, _phase, _pose == "idle" and _blink_t < 0.0)


func _draw_tag(ci: CanvasItem) -> void:
	if carrying == "":
		return
	var bob := 0.0 if Settings.reduced_motion else roundf(sin(_time * 3.0))
	var w := ComicFont.measure(carrying, true) + 6
	var r := Rect2(-roundf(w / 2.0), -32 + bob, w, 11)
	Ink.line(ci, Vector2(0, r.end.y), Vector2(0, -Figures.NIB_HEIGHT - 1), Palette.PENCIL, 0.75)
	Ink.rounded_box(ci, r, Palette.BUBBLE)
	ComicFont.draw(ci, r.position + Vector2(3, 2), carrying, Palette.RED, true)
