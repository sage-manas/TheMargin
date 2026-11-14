class_name Platform
extends AnimatableBody2D
## A plank on a drawn rail (GDD §4.2: `motion` responds on platforms). As
## drawn it shuttles from one end of its rail to the other, resting at each
## end. A `motion` word along the rail sends it to that end and holds it
## there; a `halt` word holds it where it is. It only takes words it can
## obey: a platform on an up-down rail refuses LEFT and RIGHT.
##
## Like a crate it moves in whole page units and never leaves its rail, and it
## handles Nib explicitly (Nib is on Player.LAYER): it carries Nib and any
## crate resting on top, and stops rather than move into Nib or push a rider
## into something.

const HEIGHT := 6
const SPEED := 32.0
## How long an unlabelled platform rests at each end of its rail.
const REST := 1.0
const PROBE_MARGIN := 0.05

var platform_id := ""
var slot: WordSlot
var page: ComicPage
var panel: ComicPanel
var size := Vector2(32, HEIGHT)
## 0 for a left-right rail, 1 for up-down.
var axis := 1
var rail_min := 0
var rail_max := 0
var moving := false
## Which way an unlabelled platform is heading along its rail (+1 or -1).
var shuttle := 1
var _fixed := 0
var _rest := 0.0
var _acc := 0.0


func setup(def: Dictionary) -> void:
	platform_id = def["id"]
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	size.x = float(def.get("w", 32))
	var rail: Dictionary = def["rail"]
	axis = 0 if rail.get("axis") == "x" else 1
	rail_min = int(rail["min"])
	rail_max = int(rail["max"])
	_fixed = int(position[1 - axis])
	sync_to_physics = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = size / 2.0
	add_child(cs)
	slot = WordSlot.make("%s:label" % platform_id, def.get("label", ""), def.get("loose", true), ["motion", "halt"], self, self, Vector2(size.x / 2.0, 0))
	slot.filter = obeys
	# Reachable from standing on the plank or from just beside or below it.
	slot.reach = Vector2(size.x / 2.0 + 10, 20)


## Which way a label sends a platform along a rail on `rail_axis`: -1 or +1,
## or 0 to hold. Data only: the word's category and its `dir` parameter.
static func heading_for(word: String, rail_axis: int) -> int:
	var def := WordLibrary.get_def(word)
	if def.get("category") != "motion":
		return 0
	var d: Array = def.get("dir", [0, 0])
	return int(d[rail_axis])


## A platform takes a motion word only if it runs along its rail.
func obeys(word: String) -> bool:
	return WordLibrary.category(word) != "motion" or heading_for(word, axis) != 0


## A saved or proposed position the platform could be at.
func on_rail(at: Vector2i) -> bool:
	return at[1 - axis] == _fixed and at[axis] >= rail_min and at[axis] <= rail_max


func rect() -> Rect2:
	return Rect2(global_position, size)


func on_slot_changed(_slot: WordSlot) -> void:
	_acc = 0.0
	_rest = 0.0
	queue_redraw()


func refresh(_animate := false) -> void:
	queue_redraw()


func slot_prompt_position(_s: WordSlot) -> Vector2:
	return global_position + Vector2(size.x / 2.0, -14)


func _physics_process(delta: float) -> void:
	if page == null:
		return
	var as_drawn := slot.word == ""
	var dir := 0
	if not as_drawn:
		dir = heading_for(slot.word, axis)
	elif _rest > 0.0:
		_rest -= delta
	else:
		dir = shuttle
	var blocked := dir == 0
	if not blocked:
		_acc += SPEED * delta
		while _acc >= 1.0:
			_acc -= 1.0
			if not step(dir):
				_acc = 0.0
				blocked = true
				break
			moving = true
		if blocked and as_drawn:
			shuttle = -shuttle
			_rest = REST
	if blocked and moving:
		moving = false
		if as_drawn:
			Audio.play("tick", 0.1, -8.0)
		else:
			Audio.play("land", 0.1, -6.0)
			EventBus.state_dirty.emit()
	if slot.loose and slot.word != "" and not Settings.reduced_motion:
		queue_redraw()


## Moves one unit along the rail (`dir` is -1 or +1) with everything riding
## on it. Returns false when blocked: by the end of the rail, by panel
## geometry or crates in the way, by Nib (when not riding), or when a rider
## has no room to come along.
func step(dir: int) -> bool:
	var motion := Vector2.ZERO
	motion[axis] = dir
	var along := int(position[axis]) + dir
	if along < rail_min or along > rail_max:
		return false
	var probe := motion * 0.9
	var riders := crate_riders()
	var player := page.player
	var nib_rides := player != null and carries(player)
	# The plank's own probe ignores what it carries.
	for c in riders:
		add_collision_exception_with(c)
	var hit := test_move(global_transform, probe, null, PROBE_MARGIN)
	for c in riders:
		remove_collision_exception_with(c)
	if hit:
		return false
	if nib_rides:
		if motion.y <= 0.0:
			for c in riders:
				player.add_collision_exception_with(c)
			var nib_hit := player.test_move(player.global_transform, probe, null, Player.HEADROOM if motion.y < 0.0 else PROBE_MARGIN)
			for c in riders:
				player.remove_collision_exception_with(c)
			if nib_hit:
				return false
	elif player != null:
		var body := player.collision_rect().grow(-0.01)
		if Rect2(global_position + motion, size).intersects(body) and not rect().intersects(body):
			return false
	# Going down, riders follow into the space the plank leaves; otherwise
	# each needs room of its own.
	if motion.y <= 0.0:
		var nib_shift := motion if nib_rides else Vector2.ZERO
		for c in riders:
			if not c.can_step(Vector2i(motion), nib_shift):
				return false
	position += motion
	if nib_rides:
		player.position += motion
	for c in riders:
		c.shift(motion)
	queue_redraw()
	return true


## Crates resting on the plank.
func crate_riders() -> Array[Crate]:
	var out: Array[Crate] = []
	for c: Crate in page.crates.values():
		if c.panel == panel and _rests_on(c.rect()):
			out.append(c)
	return out


## Nib is standing on the plank.
func carries(player: Player) -> bool:
	return _rests_on(player.collision_rect())


func _rests_on(r: Rect2) -> bool:
	var top := global_position.y
	return absf(r.end.y - top) <= 1.0 and r.end.x > global_position.x and r.position.x < global_position.x + size.x


func _draw() -> void:
	_draw_rail()
	# A plank, heavy-inked like everything Nib can use, with a wood grain.
	var plank := Rect2(Vector2.ZERO, size)
	Ink.box(self, plank, Palette.OCHRE, Palette.INK, Ink.W_THING)
	Ink.line(self, Vector2(3, 2.2), Vector2(size.x - 6, 2.2), Palette.WOOD_DARK, 0.6)
	# The label hangs on a tag under the middle of the plank.
	var tag := LabelTag.draw(self, Vector2(size.x / 2.0, HEIGHT + 1.5), slot, 16.0)
	for x in [tag.position.x + 3, tag.end.x - 3]:
		Ink.line(self, Vector2(x, HEIGHT - 0.5), Vector2(x, tag.position.y), Palette.INK, 0.6)


## The rail is a dotted pencil guide fixed to the panel, from where the plank
## rests at one end to where it rests at the other, with a stop at each end.
func _draw_rail() -> void:
	var from := -position
	from[axis] += rail_min
	from[1 - axis] += _fixed
	var length := float(rail_max - rail_min)
	var col := Palette.PENCIL
	if axis == 1:
		var x := size.x / 2.0
		var top := from.y + HEIGHT / 2.0
		Ink.dashed(self, Vector2(x - 0.4, top), length, 1, 0.8, col, 2.0, 2.0)
		Ink.line(self, Vector2(x - 3.5, top - 0.5), Vector2(x + 3.5, top - 0.5), col, 1.0)
		Ink.line(self, Vector2(x - 3.5, top + length + 1.5), Vector2(x + 3.5, top + length + 1.5), col, 1.0)
	else:
		var y := HEIGHT / 2.0
		var left := from.x
		Ink.dashed(self, Vector2(left, y - 0.4), length + size.x, 0, 0.8, col, 2.0, 2.0)
		Ink.line(self, Vector2(left - 0.5, y - 3.5), Vector2(left - 0.5, y + 3.5), col, 1.0)
		Ink.line(self, Vector2(left + length + size.x + 0.5, y - 3.5), Vector2(left + length + size.x + 0.5, y + 3.5), col, 1.0)
