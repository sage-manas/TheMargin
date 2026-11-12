class_name SketchTool
extends Node2D
## A tool in Nib's hand that works on pencil sketches: the eraser (X) and
## the ink in Nib's hat (C). Like PlayerInteraction does for words, it picks
## the sketch in reach and resolves a verb; subclasses say which sketches
## they work on, what the verb is, and what acting does. Verbs in ACTS act;
## anything else is a refusal the prompt explains.

## How far Nib's body may be from a sketch's edge and still reach it.
const REACH := Vector2(10, 16)

var page: ComicPage
var player: Player
var target: Sketch
var verb := ""
## Which of Nib's tools this is, so two prompts and pip rows stack (0 = lowest).
var row := 0
var _showing := false


func setup(owner_page: ComicPage, owner_player: Player, tool_row := 0) -> void:
	page = owner_page
	player = owner_player
	row = tool_row
	z_index = 20


## The gap between two rects along each axis (zero where they overlap).
static func gap(a: Rect2, b: Rect2) -> Vector2:
	return Vector2(
		maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x)),
		maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y)))


# --- overridden by each tool -------------------------------------------------

func has_tool() -> bool:
	return false


## Input action and the key shown on the prompt.
func action() -> String:
	return ""


func key() -> String:
	return ""


func works_on(_s: Sketch) -> bool:
	return false


func verb_on(_s: Sketch) -> String:
	return ""


func acts(v: String) -> bool:
	return false


func label() -> String:
	return ""


## Applies `verb` to `target`.
func act() -> void:
	pass


## [held, capacity, colour] for the pips above Nib's head.
func pips() -> Array:
	return [0, 0, Palette.PENCIL]


# --- shared -------------------------------------------------------------------

func _process(_delta: float) -> void:
	_refresh_target()
	# Redraw only while pips or a prompt are up (they follow Nib), and once
	# more to clear them.
	var p := pips()
	var showing: bool = target != null or int(p[0]) > 0
	if showing or _showing:
		queue_redraw()
	_showing = showing


func _refresh_target() -> void:
	var best: Sketch = null
	var best_d := INF
	if has_tool() and player.can_act():
		var here := page.player_panel()
		var body := player.collision_rect()
		for s: Sketch in page.sketches.values():
			if s.panel != here or not works_on(s):
				continue
			var g := gap(body, s.rect())
			if g.x > REACH.x or g.y > REACH.y:
				continue
			# The sketch under Nib's feet is the fallback: standing on one step
			# and reaching for the next should pick the next.
			var d := g.x + g.y
			if absf(body.end.y - s.rect().position.y) <= 1.0 and g.x == 0.0:
				d += REACH.x + REACH.y
			if d < best_d:
				best = s
				best_d = d
	if target and target != best:
		target.unhighlight(self)
	target = best
	verb = ""
	if target:
		target.highlight(self)
		verb = verb_on(target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action()) and target:
		perform()
		get_viewport().set_input_as_handled()


func perform() -> bool:
	if target == null:
		return false
	if not acts(verb):
		Audio.play("deny")
		return false
	act()
	EventBus.state_dirty.emit()
	return true


func _draw() -> void:
	if not has_tool():
		return
	var p := pips()
	var held: int = p[0]
	var holds: int = p[1]
	var lift := row * 3.0
	if held > 0 or target:
		var head := to_local(player.global_position) + Vector2(-(holds * 3 - 1) / 2.0, -18 - lift)
		for i in holds:
			Ink.dot(self, head + Vector2(i * 3 + 1, 1), 1.0, p[2] if i < held else Palette.SHADOW)
	if target == null:
		return
	var text := label()
	var acting := acts(verb)
	Prompt.draw(self, _prompt_at(), key(), text, acting)


## Above Nib's head (and above a carried word's tag), not above the sketch:
## a crate resting on a shelf would hide a prompt drawn there. A second tool
## with a target stacks its prompt above the first.
func _prompt_at() -> Vector2:
	var y := -33.0 if player.carrying == "" else -46.0
	y -= 13.0 * _prompts_below()
	return to_local(player.global_position + Vector2(0, y))


func _prompts_below() -> int:
	var n := 0
	for t: SketchTool in page.tools:
		if t.row < row and t.target != null:
			n += 1
	return n
