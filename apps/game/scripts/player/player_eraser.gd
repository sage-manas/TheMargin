class_name PlayerEraser
extends SketchTool
## The eraser in Nib's hand (GDD §4.3): erase a drawn pencil sketch, or
## restore a smudge with crumbs. Ink is permanent, so inked sketches are
## never a target. Crumbs are never stored; they are what the page's
## sketches add up to (ComicPage.crumbs()).

## How many crumbs an eraser holds unless the page says otherwise. You can't
## erase more than you can put back.
const HOLDS := 3


## What pressing erase would do (TDD §3.5). "erase" and "restore" act;
## "full", "short" and "blocked" are refusals the prompt explains.
static func verb_for(drawn: bool, cost: int, crumbs: int, holds: int, blocked: bool) -> String:
	if drawn:
		return "erase" if crumbs + cost <= holds else "full"
	if crumbs < cost:
		return "short"
	return "blocked" if blocked else "restore"


func has_tool() -> bool:
	return page.has_eraser()


func action() -> String:
	return "erase"


func key() -> String:
	return "X"


func works_on(s: Sketch) -> bool:
	return not s.inked


func verb_on(s: Sketch) -> String:
	# A faint sketch has nothing to stand in the way of when drawn back.
	return verb_for(s.drawn, s.crumbs, page.crumbs(), page.eraser_holds, s.solid_when_drawn() and page.sketch_blocked(s))


func acts(v: String) -> bool:
	return v == "erase" or v == "restore"


func label() -> String:
	return {
		"erase": "ERASE",
		"restore": "RESTORE",
		"full": "ERASER FULL",
		"short": "NEEDS %d CRUMB%s" % [target.crumbs, "" if target.crumbs == 1 else "S"],
		"blocked": "SOMETHING IS IN THE WAY",
	}.get(verb, "")


func act() -> void:
	if verb == "erase":
		target.set_drawn(false)
		Audio.play("rub")
		EventBus.sketch_erased.emit(target.sketch_id)
	else:
		target.set_drawn(true)
		Audio.play("scratch")
		EventBus.sketch_restored.emit(target.sketch_id)


func pips() -> Array:
	return [page.crumbs(), page.eraser_holds, Palette.PENCIL]
