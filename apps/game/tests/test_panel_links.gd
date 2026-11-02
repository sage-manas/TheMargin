extends RefCounted
## The panel link rules (GDD §4.1) as a pure function.


func _panel(id: String, x: int, y: int, w: int, h: int, openings: Array) -> Dictionary:
	return {"id": id, "rect": Rect2i(x, y, w, h), "openings": openings}


func test_horizontal_link_requires_matching_floors(t) -> void:
	var a := _panel("a", 16, 16, 100, 100, [{"side": "right", "from": 60, "to": 84}])
	var b := _panel("b", 124, 16, 100, 100, [{"side": "left", "from": 60, "to": 84}])
	var links := PanelLinks.compute([a, b])
	t.eq(links.size(), 1, "aligned floors link")
	t.eq(links[0].axis, "h", "axis")
	t.eq(links[0].from, 76, "span from (page)")
	t.eq(links[0].to, 100, "span to = floor line")
	b.rect = Rect2i(124, 24, 100, 100)
	t.eq(PanelLinks.compute([a, b]).size(), 0, "floors 8 px apart do not link")


func test_link_requires_exact_gutter(t) -> void:
	var a := _panel("a", 16, 16, 100, 100, [{"side": "right", "from": 60, "to": 84}])
	var b := _panel("b", 132, 16, 100, 100, [{"side": "left", "from": 60, "to": 84}])
	t.eq(PanelLinks.compute([a, b]).size(), 0, "a wider gap is not a gutter")


func test_short_overlap_is_not_a_passage(t) -> void:
	var a := _panel("a", 16, 16, 100, 100, [{"side": "right", "from": 70, "to": 84}])
	var b := _panel("b", 124, 16, 100, 100, [{"side": "left", "from": 60, "to": 84}])
	t.eq(PanelLinks.compute([a, b]).size(), 0, "14 px is shorter than MIN_PASSAGE_H")


func test_vertical_link_uses_overlap(t) -> void:
	var a := _panel("a", 16, 16, 100, 100, [{"side": "bottom", "from": 40, "to": 64}])
	var b := _panel("b", 24, 124, 100, 100, [{"side": "top", "from": 40, "to": 64}])
	var links := PanelLinks.compute([a, b])
	t.eq(links.size(), 1, "stacked openings link")
	t.eq(links[0].axis, "v", "axis")
	t.eq(links[0].from, 64, "overlap from")
	t.eq(links[0].to, 80, "overlap to")


func test_openings_must_face_each_other(t) -> void:
	var a := _panel("a", 16, 16, 100, 100, [{"side": "left", "from": 60, "to": 84}])
	var b := _panel("b", 124, 16, 100, 100, [{"side": "right", "from": 60, "to": 84}])
	t.eq(PanelLinks.compute([a, b]).size(), 0, "openings on the far sides never link")


func test_gaps_are_local_to_each_panel(t) -> void:
	var a := _panel("a", 16, 16, 100, 100, [{"side": "right", "from": 60, "to": 84}])
	var b := _panel("b", 124, 16, 100, 100, [{"side": "left", "from": 60, "to": 84}])
	var links := PanelLinks.compute([a, b])
	var ga := PanelLinks.gaps_for("a", a.rect, links)
	var gb := PanelLinks.gaps_for("b", b.rect, links)
	t.eq(ga, [{"side": "right", "from": 60, "to": 84}], "gap on a")
	t.eq(gb, [{"side": "left", "from": 60, "to": 84}], "gap on b")


func test_subtract_intervals(t) -> void:
	t.eq(PanelLinks.subtract_intervals(0, 100, [[20, 30], [50, 60]]), [[0, 20], [30, 50], [60, 100]], "two holes")
	t.eq(PanelLinks.subtract_intervals(0, 100, [[-10, 10]]), [[10, 100]], "hole past the start")
	t.eq(PanelLinks.subtract_intervals(0, 100, [[0, 100]]), [], "fully removed")


func test_page_one_alignments(t) -> void:
	# The designed solution positions of the lifted panel P3 (GDD §6).
	var def := ComicPage.load_def("ch01_p01")
	var infos := {}
	for pd: Dictionary in def.panels:
		var r: Array = pd.rect
		infos[pd.id] = {"id": pd.id, "rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), "openings": [] if pd.get("pencil", false) else pd.get("openings", [])}
	var at := func(y: int) -> Array:
		var p3: Dictionary = infos["p3"].duplicate()
		p3.rect = Rect2i(416, y, 208, 120)
		var list := [infos["p1"], infos["p2"], p3, infos["p4"], infos["p5"]]
		return PanelLinks.compute(list).map(func(l: Dictionary) -> String: return "%s-%s" % [l.a, l.b])
	t.eq(at.call(16), ["p1-p2"], "start: only p1-p2 linked")
	t.eq(at.call(40), ["p1-p2", "p2-p3"], "y=40: floors of p2 and p3 line up")
	t.eq(at.call(72), ["p1-p2", "p3-p5"], "y=72: the pit drops into p5")
