extends RefCounted
## Builds the real page 1.1 and plays the designed solution through real
## physics and public gameplay APIs (GDD §6 beat sheet).


func _build(t, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("ch01_p01"), state, player)
	await t.frames(2)
	return page


func _walk_until(t, page: ComicPage, action: String, cond: Callable, max_frames := 600) -> bool:
	Input.action_press(action)
	var ok := false
	for i in max_frames:
		await t.root.get_tree().physics_frame
		if cond.call():
			ok = true
			break
	Input.action_release(action)
	await t.frames(10)
	return ok


func _x_in(page: ComicPage, panel_id: String, local_x: float) -> Callable:
	return func() -> bool: return page.player_panel() == page.panels[panel_id] and page.player.position.x >= page.panels[panel_id].position.x + local_x


func test_full_solution(t) -> void:
	var page: ComicPage = await _build(t)
	var p3: ComicPanel = page.panels["p3"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)

	# 1. Walk from P1 across the first (already linked) gutter into P2.
	t.ok(await _walk_until(t, page, "move_right", _x_in(page, "p2", 120)), "crossed P1 → P2")

	# 2. P3's floor doesn't line up yet: the border holds.
	await _walk_until(t, page, "move_right", func() -> bool: return false, 90)
	t.eq(page.player_panel(), page.panels["p2"], "sealed border stops the walk")

	# 3. Slide P3 down until the floors line up.
	page.move_panel_toward(p3, Vector2i(416, 40))
	t.eq(Vector2i(p3.position), Vector2i(416, 40), "P3 slid to the aligned position")
	t.eq(page.links.size(), 2, "P2-P3 link formed")

	# 4. Walk into P3 up to the neighbour and take OPEN out of the sentence.
	t.ok(await _walk_until(t, page, "move_right", _x_in(page, "p3", 82)), "entered P3")
	t.eq(page.interaction.verb, "take", "neighbour's bold word in reach")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "OPEN", "carrying OPEN")
	t.eq(page.slots["nb:0"].word, "", "sentence now has a gap")

	# 5. Ride P3 down; the pit lines up with P5 and Nib drops through.
	var before := page.player.position
	page.move_panel_toward(p3, Vector2i(416, 72))
	t.eq(page.player.position - before, Vector2(0, 32), "Nib moved with the panel")
	t.ok(await _walk_until(t, page, "move_right", func() -> bool: return page.player_panel() == page.panels["p5"], 400), "fell through the gutter into P5")

	# 6. Walk to the door and swap OPEN for SHUT.
	t.ok(await _walk_until(t, page, "move_right", func() -> bool: return page.interaction.verb == "swap", 400), "door label in reach")
	page.interaction.perform()
	var door: Door = page.doors[0]
	t.ok(door.is_open, "door obeys OPEN")
	t.eq(page.interaction.carrying, "SHUT", "now carrying SHUT")

	# 7. Walk through the open door.
	var reached: bool = await _walk_until(t, page, "move_right", func() -> bool: return exited[0], 300)
	t.ok(reached, "exit reached (player at %s, doorway %s)" % [page.player.position, door.doorway_rect()])
	page.queue_free()
	await t.frames(1)


func test_panel_refuses_while_in_gutter(t) -> void:
	var page: ComicPage = await _build(t)
	# Stand in the P1-P2 gutter tunnel.
	page.player.position = Vector2(212, 144)
	await t.frames(2)
	t.ok(page.is_player_in_gutter(), "standing in the gutter")
	t.eq(page.move_panel_toward(page.panels["p3"], Vector2i(416, 40)), 0, "no panel moves while in a gutter")
	page.queue_free()
	await t.frames(1)


func test_state_round_trip(t) -> void:
	var page: ComicPage = await _build(t)
	page.move_panel_toward(page.panels["p3"], Vector2i(416, 40))
	page.slots["nb:0"].word = ""
	page.slots["door1:label"].put("OPEN")
	var state := page.capture_state()
	page.queue_free()
	await t.frames(1)

	var restored: ComicPage = await _build(t, state, {"position": null, "carrying": "SHUT"})
	t.eq(Vector2i(restored.panels["p3"].position), Vector2i(416, 40), "panel position restored")
	t.eq(restored.slots["door1:label"].word, "OPEN", "door label restored")
	t.ok(restored.doors[0].is_open, "door state follows its label")
	t.eq(restored.interaction.carrying, "SHUT", "carried word restored")
	t.eq(restored.links.size(), 2, "links recomputed from positions")
	t.ok(state["fired"].has("caption_doubt"), "sliding P3 into place fired the narrator trigger")
	t.eq(restored.captions["cap2"].text, "AND THAT WAS ALL|THERE WAS...|WASN'T IT?", "rewritten caption restored without replaying")
	restored.queue_free()
	await t.frames(1)


func test_invalid_state_is_ignored(t) -> void:
	var state := {"panels": {"p3": [416, 41], "p1": [0, 0]}, "slots": {"door1:label": "BANANA", "ghost:0": "OPEN"}}
	var page: ComicPage = await _build(t, state, {"position": [5000, 5000], "carrying": "NOPE"})
	t.eq(Vector2i(page.panels["p3"].position), Vector2i(416, 16), "off-grid position rejected")
	t.eq(Vector2i(page.panels["p1"].position), Vector2i(16, 16), "fixed panels never move")
	t.eq(page.slots["door1:label"].word, "SHUT", "unknown word rejected")
	t.eq(page.player.position, page.spawn, "out-of-page position falls back to spawn")
	t.eq(page.interaction.carrying, "", "unknown carried word dropped")
	page.queue_free()
	await t.frames(1)
