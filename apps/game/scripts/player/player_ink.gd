class_name PlayerInk
extends SketchTool
## The ink in Nib's hat (GDD §4.4). Ink can only trace an existing pencil
## sketch, never draw freehand: C over a traceable sketch spends its ink
## cost (the dots on it) and turns it into ink, which is solid and permanent.
## Ink in the hat is never stored; it is the drops collected on the page
## less what tracing has spent (ComicPage.ink()).

## How many drops Nib's hat holds unless the page says otherwise.
const HOLDS := 3


## What pressing trace would do. "trace" acts; "smudged" (nothing left to
## trace), "short" and "blocked" are refusals the prompt explains.
static func verb_for(drawn: bool, cost: int, ink: int, blocked: bool) -> String:
	if not drawn:
		return "smudged"
	if ink < cost:
		return "short"
	return "blocked" if blocked else "trace"


func has_tool() -> bool:
	return page.has_ink()


func action() -> String:
	return "trace"


func key() -> String:
	return "C"


func works_on(s: Sketch) -> bool:
	return s.traceable() and not s.inked


func verb_on(s: Sketch) -> String:
	# Tracing a faint sketch makes it solid, so not around Nib or a crate.
	return verb_for(s.drawn, s.ink_cost, page.ink(), not s.solid_when_drawn() and page.sketch_blocked(s))


func acts(v: String) -> bool:
	return v == "trace"


func label() -> String:
	return {
		"trace": "TRACE IN INK",
		"smudged": "NOTHING LEFT TO TRACE",
		"short": "NEEDS %d DROP%s" % [target.ink_cost, "" if target.ink_cost == 1 else "S"],
		"blocked": "SOMETHING IS IN THE WAY",
	}.get(verb, "")


func act() -> void:
	target.set_inked()
	Audio.play("ink")
	EventBus.sketch_inked.emit(target.sketch_id)


func pips() -> Array:
	return [page.ink(), page.ink_holds, Palette.INK]
