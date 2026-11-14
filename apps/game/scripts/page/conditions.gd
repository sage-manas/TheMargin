class_name Conditions
extends RefCounted
## When a feature, character or prop is there (GDD §4.7, §4.8). A condition
## is a string: a scene ("later", "night"), or a switch set from a close-up,
## optionally negated with "!", joined with "&". "" is always met.

const SCENES := ["later", "night"]


static func met(expr: String, scene: String, switches: Dictionary) -> bool:
	if expr.strip_edges() == "":
		return true
	for part in expr.split("&"):
		var term := part.strip_edges()
		var negate := term.begins_with("!")
		if negate:
			term = term.substr(1)
		var value: bool = scene == term if SCENES.has(term) else bool(switches.get(term, false))
		if value == negate:
			return false
	return true


## The names a condition refers to (for page validation).
static func terms(expr: String) -> Array:
	var out := []
	for part in expr.split("&"):
		var term := part.strip_edges().trim_prefix("!")
		if term != "":
			out.append(term)
	return out
