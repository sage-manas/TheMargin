extends RefCounted
## Swapping panels (GDD §4.9) and stretching borders (GDD §4.10), on the
## sandboxes sb_swap and sb_stretch, through real physics and the same calls
## the reader's hand makes.


func _build(t, id: String, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def(id), state, player)
	await t.frames(2)
	return page


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


func _walk_until(t, action: String, cond: Callable, max_frames := 600) -> bool:
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


## The door room comes first in the reading order, so it's out of reach.
## Swapping it with the hall puts it next to Nib's room, and links follow.
func test_swap_reading_order(t) -> void:
	var page: ComicPage = await _build(t, "sb_swap")
	var door_room: ComicPanel = page.panels["door_room"]
	var start: ComicPanel = page.panels["start"]
	var hall: ComicPanel = page.panels["hall"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "start" and l.b == "hall"), "Nib's room opens onto the hall")
	t.ok(page.swap_panels(door_room, hall), "door room and hall swap")
	t.eq(Vector2i(door_room.position), Vector2i(416, 16), "the door room is now last")
	t.eq(Vector2i(hall.position), Vector2i(16, 16), "the hall first")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "start" and l.b == "door_room"), "and Nib's room opens onto the door")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "through the door")
	await _free(t, page)


## Nib travels with a swapped panel; a pinned or mismatched one refuses.
func test_swap_carries_nib_and_refuses(t) -> void:
	var page: ComicPage = await _build(t, "sb_swap")
	var start: ComicPanel = page.panels["start"]
	var door_room: ComicPanel = page.panels["door_room"]
	var before := page.player.position - start.position
	t.ok(page.swap_panels(start, door_room), "Nib's room swaps with the door room")
	await t.frames(3)
	t.eq(page.player_panel(), start, "Nib went with it")
	t.ok((page.player.position - start.position).distance_to(before) < 1.0, "to the same spot in the room")
	t.ok(not page.swap_panels(start, start), "not with itself")
	page.panels["hall"].swap_group = "other"
	t.ok(not page.swap_panels(start, page.panels["hall"]), "not across groups")
	await _free(t, page)


## Swapped places are saved and restored, but only as a rearrangement.
func test_swap_round_trip(t) -> void:
	var page: ComicPage = await _build(t, "sb_swap")
	page.swap_panels(page.panels["door_room"], page.panels["hall"])
	var st := page.capture_state()
	await _free(t, page)
	page = await _build(t, "sb_swap", st)
	t.eq(Vector2i(page.panels["door_room"].position), Vector2i(416, 16), "restored")
	await _free(t, page)
	page = await _build(t, "sb_swap", {"panels": {"door_room": [416, 16], "start": [416, 16], "hall": [16, 16]}})
	t.eq(Vector2i(page.panels["door_room"].position), Vector2i(16, 16), "an impossible arrangement is ignored")
	await _free(t, page)


## Stretching the room's border across the gap links it to the next room;
## the floor runs to the border wherever it is.
func test_stretch_across_the_gap(t) -> void:
	var page: ComicPage = await _build(t, "sb_stretch")
	var a: ComicPanel = page.panels["a"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.eq(page.links.size(), 0, "too far to link")
	t.eq(page.stretch_panel_toward(a, 400), 13, "stretched to its widest")
	t.eq(a.size.x, 304, "304 wide")
	t.eq(a.solids[0].size.x, 304, "the floor follows the border")
	t.eq(page.links.size(), 1, "now it links")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "along the stretched floor and out")
	await _free(t, page)


## A border never cuts through what is in the room, or through Nib.
func test_stretch_refusals(t) -> void:
	var page: ComicPage = await _build(t, "sb_stretch")
	var a: ComicPanel = page.panels["a"]
	page.stretch_panel_toward(a, 120)
	t.ok(a.size.x > 120, "the lamp stops it short of its narrowest (%s)" % a.size.x)
	t.ok(float(a.size.x) - PageConst.BORDER >= a.content_right(), "nothing is cut")
	page.stretch_panel_toward(a, 304)
	page.player.position = a.position + Vector2(280, 128)
	page.player.velocity = Vector2.ZERO
	await t.frames(5)
	page.stretch_panel_toward(a, 200)
	t.ok(a.position.x + a.size.x - PageConst.BORDER >= page.player.collision_rect().end.x, "the border stops at Nib")
	var st := page.capture_state()
	t.eq(st["sizes"], {"a": [a.size.x, 144]}, "the width is saved")
	await _free(t, page)
	page = await _build(t, "sb_stretch", {"sizes": {"a": [304, 144]}})
	t.eq(page.panels["a"].size.x, 304, "and restored")
	t.eq(page.links.size(), 1, "with its link")
	await _free(t, page)
