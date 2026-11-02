class_name PanelLinks
extends RefCounted
## Pure solver for "two panels connect where their floors line up across the
## gutter" (GDD §4.1). No nodes, no state: panels in, links out.
##
## Panel input: {id: String, rect: Rect2i, openings: Array[{side, from, to}]}
##   `from`/`to` are panel-local offsets along the side (y for left/right,
##   x for top/bottom).
## Link output: {a, b, axis: "h"|"v", from, to}
##   `a` is the left/top panel; from/to are page coordinates along the gutter.


static func compute(panels: Array) -> Array:
	var links := []
	for a: Dictionary in panels:
		for b: Dictionary in panels:
			if a.id == b.id:
				continue
			var ra: Rect2i = a.rect
			var rb: Rect2i = b.rect
			if ra.end.x + PageConst.GUTTER == rb.position.x:
				_link_horizontal(a, b, links)
			if ra.end.y + PageConst.GUTTER == rb.position.y:
				_link_vertical(a, b, links)
	return links


static func _openings(panel: Dictionary, side: String) -> Array:
	return panel.get("openings", []).filter(func(o: Dictionary) -> bool: return o.side == side)


static func _link_horizontal(a: Dictionary, b: Dictionary, links: Array) -> void:
	var ra: Rect2i = a.rect
	var rb: Rect2i = b.rect
	for oa: Dictionary in _openings(a, "right"):
		for ob: Dictionary in _openings(b, "left"):
			var a0: int = ra.position.y + int(oa.from)
			var a1: int = ra.position.y + int(oa.to)
			var b0: int = rb.position.y + int(ob.from)
			var b1: int = rb.position.y + int(ob.to)
			# Floors (the bottom of each opening) must line up exactly.
			if a1 != b1:
				continue
			var lo := maxi(a0, b0)
			if a1 - lo >= PageConst.MIN_PASSAGE_H:
				links.append({"a": a.id, "b": b.id, "axis": "h", "from": lo, "to": a1})


static func _link_vertical(a: Dictionary, b: Dictionary, links: Array) -> void:
	var ra: Rect2i = a.rect
	var rb: Rect2i = b.rect
	for oa: Dictionary in _openings(a, "bottom"):
		for ob: Dictionary in _openings(b, "top"):
			var lo := maxi(ra.position.x + int(oa.from), rb.position.x + int(ob.from))
			var hi := mini(ra.position.x + int(oa.to), rb.position.x + int(ob.to))
			if hi - lo >= PageConst.MIN_PASSAGE_W:
				links.append({"a": a.id, "b": b.id, "axis": "v", "from": lo, "to": hi})


## The border gaps one panel must open for the given links, in panel-local
## coordinates: Array[{side, from, to}].
static func gaps_for(panel_id: String, rect: Rect2i, links: Array) -> Array:
	var gaps := []
	for l: Dictionary in links:
		if l.axis == "h":
			if l.a == panel_id:
				gaps.append({"side": "right", "from": l.from - rect.position.y, "to": l.to - rect.position.y})
			elif l.b == panel_id:
				gaps.append({"side": "left", "from": l.from - rect.position.y, "to": l.to - rect.position.y})
		else:
			if l.a == panel_id:
				gaps.append({"side": "bottom", "from": l.from - rect.position.x, "to": l.to - rect.position.x})
			elif l.b == panel_id:
				gaps.append({"side": "top", "from": l.from - rect.position.x, "to": l.to - rect.position.x})
	return gaps


static func key(l: Dictionary) -> String:
	return "%s|%s|%s|%d|%d" % [l.a, l.b, l.axis, l.from, l.to]


## Subtracts gap intervals from [lo, hi]; returns the remaining solid intervals.
static func subtract_intervals(lo: int, hi: int, gaps: Array) -> Array:
	var segments := [[lo, hi]]
	for g: Array in gaps:
		var next := []
		for s: Array in segments:
			if g[1] <= s[0] or g[0] >= s[1]:
				next.append(s)
				continue
			if g[0] > s[0]:
				next.append([s[0], g[0]])
			if g[1] < s[1]:
				next.append([g[1], s[1]])
		segments = next
	return segments
