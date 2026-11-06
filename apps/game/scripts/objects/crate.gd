class_name Crate
extends AnimatableBody2D
## A crate that obeys its label (GDD §4.2). A `motion` word moves it that way
## until something stops it; a `halt` word holds it where it is, even in mid
## air; with no label it is as drawn and falls. A `mass` word leaves it as
## drawn (it falls) but changes what it weighs on a button; a LIGHT crate
## drifts down slowly. It moves in whole pixels and
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
	slot = WordSlot.make("%s:label" % crate_id, def.get("label", ""), def.get("loose", true), ["motion", "halt", "mass"], self, self, Vector2(SIZE.x / 2.0, SIZE.y))
	# Reachable from beside the crate or from standing on it.
	slot.reach = Vector2(22, 20)


## Which way a label sends a crate, one pixel per step. Data only: the word's
## category and its `dir` parameter.
static func heading_for(word: String) -> Vector2i:
	if word == "":
		return Vector2i.DOWN
	var def := WordLibrary.get_def(word)
	match def.get("category"):
		"motion":
			var d: Array = def.get("dir", [0, 0])
			return Vector2i(int(d[0]), int(d[1]))
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


## Moves one pixel along `dir` if nothing is in the way. Returns false when
## blocked (see can_step).
func step(dir: Vector2i) -> bool:
	if not can_step(dir):
		return false
	shift(Vector2(dir))
	return true


## Whether a one-pixel move along `dir` is clear: of panel geometry, other
## crates, the panel's own border, Nib (when not riding), or, for a rider,
## whatever is above Nib's head. `nib_shift` is where Nib will be moved to
## alongside the crate (a platform carrying both).
func can_step(dir: Vector2i, nib_shift := Vector2.ZERO) -> bool:
	var motion := Vector2(dir)
	# Probe slightly short of a full pixel so the default safe margin doesn't
	# stop the crate one pixel before a surface it should touch.
	var probe := motion * 0.9
	if test_move(global_transform, probe, null, PROBE_MARGIN):
		return false
	var inner := Rect2(Vector2.ONE * PageConst.BORDER, Vector2(panel.size) - Vector2.ONE * PageConst.BORDER * 2)
	if not inner.encloses(Rect2(position + motion, SIZE)):
		return false
	var player := page.player
	if player != null and carries(player):
		if dir.y <= 0 and player.test_move(player.global_transform, probe, null, PROBE_MARGIN):
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
	var r := Rect2(Vector2.ZERO, SIZE)
	Ink.box(self, r, Palette.OCHRE)
	# Planks and a cross brace above the label plate.
	draw_rect(Rect2(1, 4, SIZE.x - 2, 1), Palette.SHADOW)
	Ink.line(self, Vector2i(2, 6), Vector2i(int(SIZE.x) - 3, 11), Palette.SHADOW)

	# The label is stencilled on a plate across the lower face.
	var bold := slot.word != ""
	var w := PixelFont.measure(slot.word, true) + 6 if bold else 16
	var plate := Rect2(roundf(SIZE.x / 2.0 - w / 2.0), SIZE.y - 13, w, 11)
	Ink.box(self, plate, Palette.WHITE, Palette.RED if slot.highlighted else Palette.INK)
	if bold:
		var bob := 0.0 if (Settings.reduced_motion or not slot.loose) else roundf(sin(Time.get_ticks_msec() / 250.0) * 0.6)
		PixelFont.draw_centered(self, SIZE.x / 2.0, plate.position.y + 2 + bob, slot.word, Palette.RED if slot.loose else Palette.INK, true)
	else:
		draw_rect(Rect2(plate.position.x + 3, plate.position.y + 8, w - 6, 1), Palette.PENCIL)
