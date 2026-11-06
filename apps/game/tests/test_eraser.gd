extends RefCounted
## Phase 3 eraser on the sandbox page, through real physics: the eraser is
## found, pencil rubs out and leaves crumbs, crumbs draw smudges back, and
## the eraser can't hold more than it can put back (GDD §4.3).


func _build(t, state := {}, found := []) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("sb_eraser"), state, {}, found)
	await t.frames(2)
	return page


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


## Puts Nib on the floor of a panel at a panel-local x and lets it settle.
func _stand(t, page: ComicPage, panel: String, x: float, floor_y := 152.0) -> void:
	page.player.position = page.panels[panel].position + Vector2(x, floor_y)
	page.player.velocity = Vector2.ZERO
	await t.frames(4)
	page.eraser._refresh_target()


func test_verbs(t) -> void:
	t.eq(PlayerEraser.verb_for(true, 1, 0, 3, false), "erase", "pencil rubs out")
	t.eq(PlayerEraser.verb_for(true, 2, 2, 3, false), "full", "not more than the eraser holds")
	t.eq(PlayerEraser.verb_for(true, 1, 2, 3, true), "erase", "erasing is never blocked")
	t.eq(PlayerEraser.verb_for(false, 1, 1, 3, false), "restore", "crumbs draw it back")
	t.eq(PlayerEraser.verb_for(false, 2, 1, 3, false), "short", "not without enough crumbs")
	t.eq(PlayerEraser.verb_for(false, 1, 1, 3, true), "blocked", "not over Nib or a crate")
	t.eq(PlayerEraser.gap(Rect2(0, 0, 4, 4), Rect2(10, 2, 4, 4)), Vector2(6, 0), "gap between rects")


func test_found_not_given(t) -> void:
	var found := []
	var on_found := func() -> void: found.append(true)
	EventBus.eraser_found.connect(on_found)
	var page: ComicPage = await _build(t)
	t.ok(not page.has_eraser(), "Nib starts without the eraser")
	await _stand(t, page, "e1", 168)
	t.ok(page.eraser.target == null, "no eraser, no prompt beside pencil")

	await _stand(t, page, "e1", 64)
	t.ok(page.has_eraser(), "walking into the eraser picks it up")
	t.eq(found.size(), 1, "eraser_found fired once")
	t.ok(page.snapshot()["abilities"].has("eraser"), "it is an ability, for the save")
	EventBus.eraser_found.disconnect(on_found)
	await _free(t, page)

	page = await _build(t, {}, ["eraser"])
	var pickups := page.find_children("*", "EraserPickup", true, false)
	t.eq(pickups.size(), 0, "a found eraser isn't drawn again")
	await _free(t, page)


func test_erase_opens_the_wall(t) -> void:
	var page: ComicPage = await _build(t, {}, ["eraser"])
	var wall: Sketch = page.sketches["wall"]
	await _stand(t, page, "e1", 168)
	t.ok(page.player.test_move(page.player.global_transform, Vector2(16, 0)), "the pencil wall is solid")
	t.eq(page.eraser.target, wall, "the wall is in reach")
	t.eq(page.eraser.verb, "erase", "and can be erased")

	await _stand(t, page, "e1", 100, 128)
	t.ok(page.eraser.target == null, "ink is never a target")

	await _stand(t, page, "e1", 168)
	t.ok(page.eraser.perform(), "erase")
	t.ok(not wall.drawn, "the wall is a smudge")
	t.eq(page.crumbs(), 2, "it left its two crumbs")
	await t.frames(2)
	t.ok(not page.player.test_move(page.player.global_transform, Vector2(16, 0)), "Nib can walk through")
	t.eq(page.capture_state()["sketches"]["wall"], false, "saved as erased")
	await _free(t, page)


func test_holds_only_what_it_can_put_back(t) -> void:
	# The wall is already rubbed out: the eraser holds its two crumbs, all it can.
	var page: ComicPage = await _build(t, {"sketches": {"wall": false}}, ["eraser"])
	var shelf: Sketch = page.sketches["shelf"]
	var step1: Sketch = page.sketches["step1"]
	var step2: Sketch = page.sketches["step2"]
	t.eq(page.crumbs(), 2, "crumbs are derived from the sketches")

	await _stand(t, page, "e2", 92)
	t.eq(page.eraser.target, shelf, "the shelf is in reach")
	t.eq(page.eraser.verb, "full", "but the eraser is full")
	t.ok(not page.eraser.perform(), "so it refuses")
	t.ok(shelf.drawn, "and the shelf stays")

	await _stand(t, page, "e2", 150)
	t.eq(page.eraser.target, step1, "the first step's smudge is in reach")
	t.eq(page.eraser.verb, "restore", "and can be drawn back")
	t.ok(page.eraser.perform(), "restore")
	t.eq(page.crumbs(), 1, "spending a crumb")

	await _stand(t, page, "e2", 92)
	t.ok(page.eraser.perform(), "now the shelf rubs out")
	for i in 40:
		await t.root.get_tree().physics_frame
	t.ok(page.buttons["plate"].pressed, "its crate falls onto the plate")
	t.ok(page.doors[0].is_open, "which holds the door open")

	await _stand(t, page, "e2", 170, 128)
	t.eq(page.eraser.target, step2, "from the first step, the second is in reach")
	t.ok(page.eraser.perform(), "draw it back")
	t.eq(page.crumbs(), 1, "the wall's crumbs and the shelf's, less two steps")
	await _free(t, page)


func test_restore_refusals(t) -> void:
	var page: ComicPage = await _build(t, {}, ["eraser"])
	var step1: Sketch = page.sketches["step1"]
	await _stand(t, page, "e2", 150)
	t.eq(page.eraser.target, step1, "the step is in reach")
	t.eq(page.eraser.verb, "short", "but there are no crumbs yet")
	t.ok(not page.eraser.perform(), "so it refuses")

	# A sketch is never drawn back over Nib.
	page.player.position = step1.global_position + Vector2(20, 10)
	t.ok(page.sketch_blocked(step1), "Nib in the way")
	await _free(t, page)


func test_save_round_trip(t) -> void:
	var state := {"sketches": {"wall": false, "step1": true}}
	var page: ComicPage = await _build(t, state, ["eraser"])
	t.ok(not page.sketches["wall"].drawn and page.sketches["step1"].drawn, "restored")
	t.eq(page.crumbs(), 1, "with the crumbs they imply")
	var st := page.capture_state()
	t.eq(st["sketches"], {"wall": false, "shelf": true, "step1": true, "step2": false}, "captured")
	await _free(t, page)

	# A save that owes crumbs it never had starts the sketches over.
	page = await _build(t, {"sketches": {"step1": true}}, ["eraser"])
	t.ok(not page.sketches["step1"].drawn, "impossible save reset")
	t.eq(page.crumbs(), 0, "to no crumbs")
	await _free(t, page)
