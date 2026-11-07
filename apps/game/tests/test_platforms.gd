extends RefCounted
## Moving platforms on the sandbox page, through real physics (GDD §4.2):
## as drawn a plank shuttles along its rail; a motion word along the rail
## sends it to that end and STOP holds it; it carries Nib and crates and
## never moves into Nib.


func _build(t, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("sb_platforms"), state, player)
	await t.frames(2)
	return page


func _settle(t, body: Node, max_frames := 900) -> void:
	await t.frames(2)
	for i in max_frames:
		if not body.moving:
			return
		await t.root.get_tree().physics_frame


## Puts Nib's feet at a panel-local point.
func _place_nib(page: ComicPage, panel_id: String, at: Vector2) -> void:
	page.player.position = page.panels[panel_id].global_position + at
	page.player.velocity = Vector2.ZERO


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


func test_headings_are_data(t) -> void:
	t.eq(Platform.heading_for("UP", 1), -1, "UP on an up-down rail")
	t.eq(Platform.heading_for("DOWN", 1), 1, "DOWN on an up-down rail")
	t.eq(Platform.heading_for("RIGHT", 0), 1, "RIGHT on a left-right rail")
	t.eq(Platform.heading_for("LEFT", 1), 0, "LEFT has no say on an up-down rail")
	t.eq(Platform.heading_for("STOP", 0), 0, "STOP holds")
	var page: ComicPage = await _build(t)
	var lift: Platform = page.platforms["lift1"]
	var ferry: Platform = page.platforms["ferry"]
	t.ok(lift.slot.accepts_word("UP") and lift.slot.accepts_word("STOP"), "a lift takes UP and STOP")
	t.ok(not lift.slot.accepts_word("LEFT"), "a lift refuses LEFT")
	t.ok(not ferry.slot.accepts_word("DOWN"), "a ferry refuses DOWN")
	t.ok(not ferry.slot.accepts_word("HEAVY") and not ferry.slot.accepts_word("OPEN"), "platforms refuse mass and state")
	await _free(t, page)


func test_drawn_platform_shuttles(t) -> void:
	var page: ComicPage = await _build(t)
	var lift: Platform = page.platforms["lift1"]
	_place_nib(page, "m1", Vector2(32, 168))
	await t.frames(2)
	var top := INF
	for i in 360:
		await t.root.get_tree().physics_frame
		top = minf(top, lift.position.y)
	t.eq(top, 56.0, "rose to the top of its rail")
	t.eq(lift.position.x, 88.0, "never left its rail")
	var low := -INF
	for i in 360:
		await t.root.get_tree().physics_frame
		low = maxf(low, lift.position.y)
	t.eq(low, 150.0, "and came back down")
	await _free(t, page)


func test_platform_carries_nib(t) -> void:
	var page: ComicPage = await _build(t)
	var ferry: Platform = page.platforms["ferry"]
	var nib := page.player
	_place_nib(page, "m2", Vector2(112, 56))
	await t.frames(10)
	t.ok(ferry.carries(nib), "Nib stands on the ferry")
	t.eq(ferry.position.x, 96.0, "STOP holds the ferry")
	var offset := nib.position.x - ferry.global_position.x
	ferry.slot.put("RIGHT")
	await _settle(t, ferry)
	t.eq(ferry.position.x, 264.0, "RIGHT sends it to the end of its rail")
	t.ok(ferry.carries(nib), "Nib rode across")
	t.ok(absf(nib.position.x - ferry.global_position.x - offset) <= 1.0, "Nib moved with the plank, no more (%s)" % (nib.position.x - ferry.global_position.x - offset))
	await t.frames(30)
	t.eq(ferry.position.x, 264.0, "and holds there")

	# Up-down too: Nib rides the lift to the ledge.
	var lift: Platform = page.platforms["lift1"]
	lift.slot.put("DOWN")
	await _settle(t, lift)
	_place_nib(page, "m1", Vector2(104, 150))
	await t.frames(5)
	t.ok(lift.carries(nib), "Nib on the lift")
	lift.slot.take()
	lift.slot.put("UP")
	await _settle(t, lift)
	t.eq(lift.position.y, 56.0, "lift at the top")
	t.ok(lift.carries(nib), "Nib rode up")
	await _free(t, page)


func test_stop_holds_mid_rail(t) -> void:
	var page: ComicPage = await _build(t)
	var ferry: Platform = page.platforms["ferry"]
	_place_nib(page, "m2", Vector2(40, 56))
	ferry.slot.take()
	await t.frames(150)
	t.ok(ferry.position.x > 96.0, "without STOP it shuttles")
	ferry.slot.put("STOP")
	await t.frames(1)
	var held := ferry.position
	await t.frames(60)
	t.eq(ferry.position, held, "STOP holds it where it is")
	await _free(t, page)


func test_platform_does_not_crush_nib(t) -> void:
	var page: ComicPage = await _build(t)
	var lift: Platform = page.platforms["lift1"]
	var nib := page.player
	lift.slot.put("UP")
	await _settle(t, lift)
	# Stand under the lift, then send it down.
	_place_nib(page, "m1", Vector2(104, 168))
	await t.frames(5)
	lift.slot.take()
	lift.slot.put("DOWN")
	await _settle(t, lift)
	t.ok(lift.rect().end.y <= nib.collision_rect().position.y + 0.5, "the lift stopped above Nib's head")
	t.ok(lift.position.y > 56.0, "it did come down")
	await _free(t, page)


func test_lift_carries_crate_to_plate(t) -> void:
	var page: ComicPage = await _build(t)
	var lift: Platform = page.platforms["lift3"]
	var box: Crate = page.crates["box"]
	var door: Door = page.doors[0]
	_place_nib(page, "m3", Vector2(160, 184))
	await t.frames(5)
	t.ok(lift.crate_riders().has(box), "the crate rides the lift")
	t.ok(not door.is_open, "door shut")
	box.slot.put("LEFT")
	await _settle(t, box)
	t.eq(box.position.x, 112.0, "LEFT holds the crate against the shaft wall")
	lift.slot.take()
	lift.slot.put("UP")
	await _settle(t, lift)
	t.eq(lift.position.y, 88.0, "the lift reached the ledge")
	await _settle(t, box)
	t.eq(box.position, Vector2(PageConst.BORDER, 64), "the crate slid off onto the ledge")
	await t.frames(2)
	t.ok(page.buttons["plate"].pressed, "and onto the plate")
	t.ok(door.is_open, "which opens the door")
	await _free(t, page)


func test_platform_positions_are_saved(t) -> void:
	var page: ComicPage = await _build(t)
	var ferry: Platform = page.platforms["ferry"]
	_place_nib(page, "m2", Vector2(40, 56))
	ferry.slot.take()
	ferry.slot.put("RIGHT")
	await t.frames(60)
	ferry.slot.take()
	ferry.slot.put("STOP")
	await t.frames(2)
	var state := page.capture_state()
	t.eq(state["objects"]["ferry"], [int(ferry.position.x), 56], "ferry position captured")
	await _free(t, page)

	var restored: ComicPage = await _build(t, state)
	t.eq(restored.platforms["ferry"].position, Vector2(state["objects"]["ferry"][0], 56), "ferry restored mid rail")
	await _free(t, restored)

	# Off the rail, or a word the platform can't obey, is ignored.
	var bad: ComicPage = await _build(t, {"objects": {"ferry": [100, 40], "lift1": [88, 300]}, "slots": {"lift1:label": "LEFT"}})
	t.eq(bad.platforms["ferry"].position, Vector2(96, 56), "off-rail position ignored")
	t.eq(bad.platforms["lift1"].position, Vector2(88, 150), "past the rail end ignored")
	t.eq(bad.platforms["lift1"].slot.word, "", "a word across the rail is ignored")
	await _free(t, bad)


func _hold_until(t, actions: Array, cond: Callable, max_frames := 600) -> bool:
	for a: String in actions:
		Input.action_press(a)
	var ok := false
	for i in max_frames:
		await t.root.get_tree().physics_frame
		if cond.call():
			ok = true
			break
	for a: String in actions:
		Input.action_release(a)
	await t.frames(10)
	return ok


func _wait_for(t, cond: Callable, max_frames := 600) -> bool:
	return await _hold_until(t, [], cond, max_frames)


## The sandbox solved with Nib's own walk and hop, through real physics.
func test_full_solution(t) -> void:
	var page: ComicPage = await _build(t)
	var nib := page.player
	var act := page.interaction
	var lift1: Platform = page.platforms["lift1"]
	var ferry: Platform = page.platforms["ferry"]
	var lift3: Platform = page.platforms["lift3"]
	var m1: ComicPanel = page.panels["m1"]
	var m2: ComicPanel = page.panels["m2"]

	# 1. Hop onto the drawn lift while it rests at the bottom, ride it up.
	t.ok(await _hold_until(t, ["move_right"], func() -> bool: return nib.position.x >= m1.position.x + 64), "walked to the lift")
	t.ok(await _wait_for(t, func() -> bool: return lift1.position.y == 150.0 and not lift1.moving), "lift resting at the bottom")
	t.ok(await _hold_until(t, ["jump", "move_right"], func() -> bool: return lift1.carries(nib) and nib.is_on_floor(), 90), "hopped onto the lift")
	t.ok(await _wait_for(t, func() -> bool: return lift1.position.y == 56.0), "rode to the top")
	t.ok(await _hold_until(t, ["move_right"], func() -> bool: return page.player_panel() == m2 and nib.position.x >= m2.position.x + 104), "walked onto the ferry")

	# 2. Take STOP off the ferry and ride it over the pit.
	t.ok(ferry.carries(nib), "standing on the ferry")
	t.eq(act.target, ferry.slot, "the ferry's label in reach")
	act.perform()
	t.eq(act.carrying, "STOP", "carrying STOP")
	t.ok(await _wait_for(t, func() -> bool: return ferry.position.x == 264.0), "ferried across")
	t.ok(ferry.carries(nib), "Nib rode the whole way")
	t.ok(await _hold_until(t, ["move_right"], func() -> bool: return page.player_panel() == page.panels["m3"], 300), "dropped into the last panel")
	await t.frames(30)

	# 3. LEFT on the crate, UP on the lift: the crate slides onto the plate.
	t.ok(await _hold_until(t, ["move_left"], func() -> bool: return act.target == page.slots["cap_left:0"] and act.verb == "swap"), "reached LEFT")
	act.perform()
	t.ok(await _hold_until(t, ["move_left"], func() -> bool: return act.target == page.crates["box"].slot and act.verb == "place"), "reached the crate")
	act.perform()
	t.ok(await _hold_until(t, ["move_right"], func() -> bool: return act.target == page.slots["cap_up:0"] and act.verb == "take"), "reached UP")
	act.perform()
	t.ok(await _hold_until(t, ["move_left"], func() -> bool: return act.target == lift3.slot and act.verb == "swap"), "reached the lift's label")
	act.perform()
	t.eq(act.carrying, "DOWN", "carrying DOWN")
	var door: Door = page.doors[0]
	t.ok(await _wait_for(t, func() -> bool: return door.is_open, 600), "the crate pressed the plate and the door opened")
	t.ok(await _hold_until(t, ["move_right"], func() -> bool: return door.doorway_rect().has_point(nib.global_position + Vector2(0, -4))), "walked into the doorway")
	await _free(t, page)
