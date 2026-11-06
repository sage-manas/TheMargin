class_name PlayerEraser
extends Node2D
## The eraser in Nib's hand (GDD §4.3). Like PlayerInteraction does for
## words, it picks the pencil sketch in reach and resolves a verb: erase a
## drawn sketch, or restore a smudge with crumbs. Crumbs are never stored;
## they are what the page's sketches add up to (ComicPage.crumbs()).

## How many crumbs an eraser holds unless the page says otherwise. You can't
## erase more than you can put back.
const HOLDS := 3
## How far Nib's body may be from a sketch's edge and still reach it.
const REACH := Vector2(10, 16)

var page: ComicPage
var player: Player
var target: Sketch
var verb := ""


func setup(owner_page: ComicPage, owner_player: Player) -> void:
	page = owner_page
	player = owner_player
	z_index = 20


## What pressing erase would do (TDD §3.5). "erase" and "restore" act;
## "full", "short" and "blocked" are refusals the prompt explains.
static func verb_for(drawn: bool, cost: int, crumbs: int, holds: int, blocked: bool) -> String:
	if drawn:
		return "erase" if crumbs + cost <= holds else "full"
	if crumbs < cost:
		return "short"
	return "blocked" if blocked else "restore"


## The gap between two rects along each axis (zero where they overlap).
static func gap(a: Rect2, b: Rect2) -> Vector2:
	return Vector2(
		maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x)),
		maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y)))


func _process(_delta: float) -> void:
	_refresh_target()
	queue_redraw()


func _refresh_target() -> void:
	var best: Sketch = null
	var best_d := INF
	if page.has_eraser() and player.can_act():
		var here := page.player_panel()
		var body := player.collision_rect()
		for s: Sketch in page.sketches.values():
			if s.panel != here:
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
		target.highlighted = false
		target.queue_redraw()
	target = best
	verb = ""
	if target:
		target.highlighted = true
		verb = verb_for(target.drawn, target.crumbs, page.crumbs(), page.eraser_holds, page.sketch_blocked(target))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("erase") and target:
		perform()
		get_viewport().set_input_as_handled()


func perform() -> bool:
	if target == null:
		return false
	match verb:
		"erase":
			target.set_drawn(false)
			Audio.play("rub")
			EventBus.sketch_erased.emit(target.sketch_id)
		"restore":
			target.set_drawn(true)
			Audio.play("scratch")
			EventBus.sketch_restored.emit(target.sketch_id)
		_:
			Audio.play("deny")
			return false
	EventBus.state_dirty.emit()
	return true


func _draw() -> void:
	if not page.has_eraser():
		return
	var crumbs := page.crumbs()
	# Crumbs in hand: one pip per crumb the eraser holds, filled when held.
	if crumbs > 0 or target:
		var holds := page.eraser_holds
		var head := to_local(player.global_position) + Vector2(-(holds * 3 - 1) / 2.0, -18)
		for i in holds:
			var pip := Rect2(roundf(head.x) + i * 3, head.y, 2, 2)
			draw_rect(pip, Palette.PENCIL if i < crumbs else Palette.SHADOW)
	if target == null:
		return
	var label: String = {
		"erase": "ERASE",
		"restore": "RESTORE",
		"full": "ERASER FULL",
		"short": "NEEDS %d CRUMB%s" % [target.crumbs, "" if target.crumbs == 1 else "S"],
		"blocked": "SOMETHING IS IN THE WAY",
	}.get(verb, "")
	var acts := verb == "erase" or verb == "restore"
	var w := PixelFont.measure(label) + (14 if acts else 6)
	var r := Rect2(roundf(_prompt_at().x - w / 2.0), _prompt_at().y, w, 11)
	Ink.box(self, r, Palette.WHITE, Palette.INK if acts else Palette.PENCIL)
	if acts:
		Ink.box(self, Rect2(r.position + Vector2(2, 2), Vector2(7, 7)), Palette.INK, Palette.INK)
		PixelFont.draw(self, r.position + Vector2(3, 2), "X", Palette.WHITE)
		PixelFont.draw(self, r.position + Vector2(11, 2), label, Palette.INK)
	else:
		PixelFont.draw(self, r.position + Vector2(3, 2), label, Palette.PENCIL)


## Above Nib's head (and above a carried word's tag), not above the sketch:
## a crate resting on a shelf would hide a prompt drawn there.
func _prompt_at() -> Vector2:
	var y := -33.0 if player.carrying == "" else -46.0
	return to_local(player.global_position + Vector2(0, y))
