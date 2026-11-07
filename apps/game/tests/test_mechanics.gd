extends RefCounted
## Phase 3 mechanics on the sandbox page, through real physics: crates obey
## motion / halt words and fall when unlabelled; words on a panel's caption
## pin it (GDD §4.2).


func _build(t, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("sb_mechanics"), state, player)
	await t.frames(2)
	return page


func _settle(t, crate: Crate, max_frames := 600) -> void:
	await t.frames(2)
	for i in max_frames:
		if not crate.moving:
			return
		await t.root.get_tree().physics_frame


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


func test_headings_are_data(t) -> void:
	t.eq(Crate.heading_for(""), Vector2i.DOWN, "unlabelled crates fall")
	t.eq(Crate.heading_for("UP"), Vector2i.UP, "UP")
	t.eq(Crate.heading_for("RIGHT"), Vector2i.RIGHT, "RIGHT")
	t.eq(Crate.heading_for("LEFT"), Vector2i.LEFT, "LEFT")
	t.eq(Crate.heading_for("STOP"), Vector2i.ZERO, "STOP holds")
	t.eq(WordLibrary.category("HEAVY"), "mass", "HEAVY category")
	t.eq(WordLibrary.category("STOP"), "halt", "STOP category")


func test_crate_obeys_its_label(t) -> void:
	var page: ComicPage = await _build(t)
	var c: Crate = page.crates["c1"]
	page.player.position = Vector2(56, 168)
	await t.frames(30)
	t.eq(c.position, Vector2(172, 128), "unlabelled crate rests on the floor")
	t.ok(not c.slot.accepts_word("OPEN"), "crates refuse state words")

	c.slot.put("UP")
	await _settle(t, c)
	t.eq(c.position.y, float(PageConst.BORDER), "UP rises until the ceiling stops it")

	c.slot.take()
	await t.frames(20)
	t.ok(c.position.y > PageConst.BORDER, "without a label it falls again")
	c.slot.put("STOP")
	await t.frames(30)
	var held := c.position
	t.ok(held.y < 128.0, "STOP caught it in mid air")
	await t.frames(30)
	t.eq(c.position, held, "STOP holds it there")

	c.slot.take()
	await _settle(t, c)
	t.eq(c.position, Vector2(172, 128), "back on the floor")
	await _free(t, page)


func test_crate_carries_nib(t) -> void:
	var page: ComicPage = await _build(t)
	var c: Crate = page.crates["c1"]
	var nib := page.player
	nib.position = c.global_position + Vector2(8, 0)
	await t.frames(10)
	t.ok(c.carries(nib), "Nib stands on the crate")
	var start := nib.position.y
	c.slot.put("UP")
	await _settle(t, c)
	t.ok(nib.position.y < start - 100.0, "Nib rode the crate up (%s → %s)" % [start, nib.position.y])
	t.ok(c.carries(nib), "still on top")
	# The crate stops when Nib's head meets the ceiling, not when the crate does.
	var head := nib.collision_rect().position.y - c.panel.global_position.y
	t.ok(head - PageConst.BORDER >= Player.HEADROOM - 0.1 and head - PageConst.BORDER <= Player.HEADROOM + 1.0, "Nib's head stopped just under the ceiling (%s)" % head)
	t.ok(c.position.y > Player.SIZE.y, "crate stopped below Nib")
	# Touching the ceiling would wedge Nib; with headroom Nib walks off.
	var x := nib.position.x
	Input.action_press("move_left")
	await t.frames(20)
	Input.action_release("move_left")
	t.ok(nib.position.x < x - 8.0, "Nib can walk off the risen crate (%s → %s)" % [x, nib.position.x])
	await _free(t, page)


func test_crate_label_in_reach_from_on_top(t) -> void:
	var page: ComicPage = await _build(t)
	var c: Crate = page.crates["c1"]
	var nib := page.player
	nib.position = c.global_position + Vector2(30, 24)
	await t.frames(10)
	page.interaction.carrying = "UP"
	await t.frames(2)
	t.eq(page.interaction.target, c.slot, "label in reach from beside the crate")
	nib.position = c.global_position + Vector2(8, 0)
	await t.frames(10)
	t.ok(c.carries(nib), "Nib stands on the crate")
	t.eq(page.interaction.target, c.slot, "and from on top of it")
	page.interaction.perform()
	await _settle(t, c)
	t.ok(c.carries(nib) and c.position.y < 100.0, "Nib labelled the crate UP from on top and rode it")
	await _free(t, page)


func test_crate_does_not_crush_nib(t) -> void:
	var page: ComicPage = await _build(t)
	var c: Crate = page.crates["c2"]
	var nib := page.player
	# Stand in s3 in the crate's path; RIGHT pushes it toward Nib.
	nib.position = page.panels["s3"].global_position + Vector2(120, 120)
	await _settle(t, c)
	t.ok(c.rect().end.x <= nib.collision_rect().position.x + 0.5, "crate stopped at Nib")
	t.ok(c.position.x > 16.0, "crate did move")
	await _free(t, page)


func test_heavy_caption_pins_panel(t) -> void:
	var page: ComicPage = await _build(t)
	var s2: ComicPanel = page.panels["s2"]
	page.player.position = Vector2(60, 168)
	await t.frames(5)
	t.ok(s2.is_pinned(), "HEAVY pins the panel")
	t.eq(page.move_panel_toward(s2, Vector2i(320, 112)), 0, "a heavy panel won't slide")
	t.eq(page.links.size(), 1, "only s1-s2 linked")

	var heavy: WordSlot = page.slots["cap_s2:0"]
	t.eq(heavy.word, "HEAVY", "caption word is a slot")
	t.eq(heavy.panel, s2, "caption slot belongs to its panel")
	heavy.take()
	t.ok(not s2.is_pinned(), "unpinned without HEAVY")
	heavy.put("LIGHT")
	t.ok(not s2.is_pinned(), "LIGHT does not pin")
	heavy.take()
	heavy.put("STOP")
	t.ok(s2.is_pinned(), "STOP pins too")
	heavy.take()
	t.eq(page.move_panel_toward(s2, Vector2i(320, 112)), 12, "slides all the way down")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "s2" and l.b == "s3"), "s2-s3 linked")
	await _free(t, page)


func test_crate_positions_are_saved(t) -> void:
	var page: ComicPage = await _build(t)
	var c: Crate = page.crates["c1"]
	page.player.position = Vector2(56, 168)
	c.slot.put("UP")
	await t.frames(40)
	c.slot.take()
	c.slot.put("STOP")
	await t.frames(2)
	var state := page.capture_state()
	t.eq(state["objects"]["c1"], [int(c.position.x), int(c.position.y)], "crate position captured")
	t.eq(state["slots"]["c1:label"], "STOP", "crate label captured")
	await _free(t, page)

	var restored: ComicPage = await _build(t, state)
	var rc: Crate = restored.crates["c1"]
	t.eq([int(rc.position.x), int(rc.position.y)], state["objects"]["c1"], "crate restored mid air")
	await t.frames(20)
	t.eq([int(rc.position.x), int(rc.position.y)], state["objects"]["c1"], "and still held by STOP")
	await _free(t, restored)

	# A tampered position outside the panel is ignored.
	var bad: ComicPage = await _build(t, {"objects": {"c1": [600, 10]}})
	t.eq(bad.crates["c1"].position, Vector2(172, 128), "invalid crate position ignored")
	await _free(t, bad)
