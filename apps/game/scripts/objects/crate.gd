class_name Crate
extends AnimatableBody2D
## A crate that obeys its label (GDD §4.2). A `motion` word moves it that way
## until something stops it; a `halt` word holds it where it is, even in mid
## air; with no label it is as drawn and falls. A `mass` word leaves it as
## drawn (it falls) but changes what it weighs on a button; a LIGHT crate
## drifts down slowly. It moves in whole page units and
## never leaves its panel, so where it rests is a plain page fact the save
## can store.
##
## Nib is on another collision layer (Player.LAYER), so the crate's own
## collision tests ignore Nib; the crate handles Nib explicitly: it carries
## Nib when Nib stands on it and stops rather than move into Nib.

const SIZE := Vector2(24, 24)
const SPEED := 48.0
const FALL_SPEED := 150.0
const PROBE_MARGIN := 0.05
## Where Nib's feet can be to reach the label, from the crate's top.
const REACH_ABOVE := -2.0
const REACH_BELOW := SIZE.y + 20.0

var crate_id := ""
var slot: WordSlot
var page: ComicPage
var panel: ComicPanel
var moving := false
var _acc := 0.0


func setup(def: Dictionary) -> void:
	crate_id = def["id"]
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	sync_to_physics = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	cs.shape = rect
	cs.position = SIZE / 2.0
	add_child(cs)
	slot = WordSlot.make("%s:label" % crate_id, def.get("label", ""), def.get("loose", true), ["motion", "halt", "mass"], self, self, Vector2(SIZE.x / 2.0, (REACH_ABOVE + REACH_BELOW) / 2.0))
	# Reachable from standing on the crate, from beside it, or from below a
	# crate a little off the floor (riding a plank): Nib's feet anywhere from
	# REACH_ABOVE over its top down to REACH_BELOW under it.
	slot.reach = Vector2(22, (REACH_BELOW - REACH_ABOVE) / 2.0)


## Which way a label sends a crate, one unit per step. Data only: the word's
## category and its `dir` parameter.
static func heading_for(word: String) -> Vector2i:
	if word == "":
		return Vector2i.DOWN
	var def := WordLibrary.get_def(word)
	match def.get("category"):
		"motion":
			var d: Array = def.get("dir", [0, 0])
			return Vector2(int(d[0]), int(d[1]))
		"mass":
			return Vector2i.DOWN
	return Vector2i.ZERO


## What a label makes a crate weigh: its `mass` parameter, or 1 as drawn.
static func weight_for(word: String) -> float:
	var def := WordLibrary.get_def(word)
	return float(def.get("mass", 1.0)) if def.get("category") == "mass" else 1.0


func weight() -> float:
	return weight_for(slot.word)


## Fall and travel speed. Lighter crates drift; nothing falls faster than
## FALL_SPEED.
func speed() -> float:
	var category := WordLibrary.category(slot.word)
	if category == "motion":
		return SPEED
	return FALL_SPEED * minf(weight(), 1.0)


func rect() -> Rect2:
	return Rect2(global_position, SIZE)


func on_slot_changed(_slot: WordSlot) -> void:
	_acc = 0.0
	queue_redraw()


func refresh(_animate := false) -> void:
	queue_redraw()


func slot_prompt_position(_s: WordSlot) -> Vector2:
	return global_position + Vector2(SIZE.x / 2.0, -14)


func _physics_process(delta: float) -> void:
	var dir := heading_for(slot.word)
	var blocked := dir == Vector2i.ZERO or page == null
	if not blocked:
		_acc += speed() * delta
		while _acc >= 1.0:
			_acc -= 1.0
			if not step(dir):
				_acc = 0.0
				blocked = true
				break
			moving = true
	if blocked and moving:
		moving = false
		Audio.play("land", 0.1, -4.0)
		EventBus.state_dirty.emit()
	if slot.loose and slot.word != "" and not Settings.reduced_motion:
		queue_redraw()


## Moves one unit along `dir` if nothing is in the way. Returns false when
## blocked (see can_step).
func step(dir: Vector2i) -> bool:
	if not can_step(dir):
		return false
	shift(Vector2(dir))
	return true


## Whether a one-unit move along `dir` is clear: of panel geometry, other
## crates, the panel's own border, Nib (when not riding), or, for a rider,
## whatever is above Nib's head. `nib_shift` is where Nib will be moved to
## alongside the crate (a platform carrying both).
func can_step(dir: Vector2i, nib_shift := Vector2.ZERO) -> bool:
	var motion := Vector2(dir)
	# Probe slightly short of a full unit so the default safe margin doesn't
	# stop the crate one unit before a surface it should touch.
	var probe := motion * 0.9
	if test_move(global_transform, probe, null, PROBE_MARGIN):
		return false
	var inner := Rect2(Vector2.ONE * PageConst.BORDER, Vector2(panel.size) - Vector2.ONE * PageConst.BORDER * 2)
	if not inner.encloses(Rect2(position + motion, SIZE)):
		return false
	var player := page.player
	if player != null and carries(player):
		var margin := Player.HEADROOM if dir.y < 0 else PROBE_MARGIN
		if dir.y <= 0 and player.test_move(player.global_transform, probe, null, margin):
			return false
	elif player != null:
		var body := player.collision_rect().grow(-0.01)
		var moved := Rect2(global_position + motion, SIZE)
		if moved.intersects(Rect2(body.position + nib_shift, body.size)) and not rect().intersects(body):
			return false
	return true


## Moves the crate, and Nib if Nib rides it, without checking.
func shift(motion: Vector2) -> void:
	var player := page.player
	var rider := player != null and carries(player)
	position += motion
	if rider:
		player.position += motion


## Nib is standing on top of this crate.
func carries(player: Player) -> bool:
	var r := player.collision_rect()
	var top := global_position.y
	return absf(r.end.y - top) <= 1.0 and r.end.x > global_position.x and r.position.x < global_position.x + SIZE.x


func _draw() -> void:
	# A wooden crate: heavy outline (it can be used), an inner frame, planks
	# and a cross brace, nails at the corners.
	var r := Rect2(Vector2.ZERO, SIZE)
	var inner := r.grow(-3.0)
	Ink.box(self, r, Palette.OCHRE, Palette.INK, Ink.W_THING)
	Ink.rect_outline(self, inner, Palette.WOOD_DARK, 0.8)
	Ink.line(self, Vector2(inner.position.x, 7.5), Vector2(inner.end.x, 7.5), Palette.WOOD_DARK, 0.6)
	Ink.line(self, inner.position, Vector2(inner.end.x, SIZE.y - 13), Palette.WOOD_DARK, 1.0)
	for c in [Vector2(1.7, 1.7), Vector2(SIZE.x - 1.7, 1.7), Vector2(1.7, SIZE.y - 1.7), Vector2(SIZE.x - 1.7, SIZE.y - 1.7)]:
		Ink.dot(self, c, 0.5, Palette.INK)
	# The label is stencilled on a tag across the lower face.
	LabelTag.draw(self, Vector2(SIZE.x / 2.0, SIZE.y - 13), slot, 16.0)
