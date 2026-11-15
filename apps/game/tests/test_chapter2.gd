extends RefCounted
## Chapter 2 "The Border" (GDD §6b), each page solved through real physics
## and the same calls the reader's hand makes.


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


func _climb_to(t, page: ComicPage, y: float, max_frames := 900) -> bool:
	var ok := false
	for i in max_frames:
		if i % 24 == 0:
			Input.action_press("jump")
		elif i % 24 == 18:
			Input.action_release("jump")
		await t.root.get_tree().physics_frame
		if page.player.is_on_floor() and page.player.position.y <= y + 0.5:
			ok = true
			break
	Input.action_release("jump")
	await t.frames(10)
	return ok


func _exits(page: ComicPage) -> Array:
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	return exited


func _wait(t, frames: int) -> void:
	for i in frames:
		await t.root.get_tree().physics_frame


## 2.1 "Reading Order": the door comes first, so swap it to the end.
func test_page_1_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p01")
	var exited := _exits(page)
	t.ok(not page.links.any(func(l: Dictionary) -> bool: return l.b == "door_room" or l.a == "door_room"), "the door links to nothing")
	t.ok(page.swap_panels(page.panels["door_room"], page.panels["hall"]), "door room and hall swap")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "start" and l.b == "door_room"), "Nib's room now opens onto the door")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "on through the door")
	await _free(t, page)


## 2.2 "Stretch": the room reaches across the gap; arriving turns the page.
func test_page_2_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p02")
	var exited := _exits(page)
	t.eq(page.links.size(), 0, "too far to link")
	t.eq(page.stretch_panel_toward(page.panels["a"], 304), 13, "stretched across")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "into the far room, and the page turns")
	await _free(t, page)


## 2.3 "Make Room": the wide room stands in the lifted room's way until it
## is narrowed; then the lifted room rises to meet it.
func test_page_3_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p03")
	var w: ComicPanel = page.panels["w"]
	var l: ComicPanel = page.panels["l"]
	var exited := _exits(page)
	t.eq(page.move_panel_toward(l, Vector2i(432, 16)), 4, "the wide room stops the lifted one")
	page.move_panel_toward(l, Vector2i(432, 200))
	t.eq(page.stretch_panel_toward(w, 408), 7, "the room narrowed")
	t.eq(page.move_panel_toward(l, Vector2i(432, 16)), 23, "now the lifted room rises all the way")
	t.ok(page.links.size() == 1, "and links")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "out through its door")
	await _free(t, page)


## 2.4 "Someone Outside": the artist puts swaps back, unless Nib is in one
## of the rooms.
func test_page_4_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p04")
	var s: ComicPanel = page.panels["s"]
	var wall: ComicPanel = page.panels["wall"]
	var door_room: ComicPanel = page.panels["door_room"]
	var exited := _exits(page)
	t.ok(page.swap_panels(wall, door_room), "the reader swaps the wall and the door")
	await _wait(t, 120)
	t.eq(Vector2i(door_room.position), Vector2i(416, 16), "the artist puts them back")
	t.eq(page.captions["artist"].text, "LEAVE THEM WHERE|I PUT THEM.", "and says so")
	t.ok(page.swap_panels(s, wall), "now swap the room Nib is in")
	await _wait(t, 120)
	t.eq(Vector2i(s.position), Vector2i(216, 16), "the artist can't move it")
	t.eq(page.captions["artist"].text, "...NOT WHILE|THEY'RE IN IT.", "and says that")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "next to the door now, and out")
	await _free(t, page)


## 2.5 "Room for Later": the room is too narrow to hold LATER until it is
## stretched; then the vine grows to the way out.
func test_page_5_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p05")
	var n: ComicPanel = page.panels["n"]
	var later: SceneCard = page.cards["later"]
	var exited := _exits(page)
	t.ok(not page.move_card(later, n), "no room for LATER")
	t.eq(page.stretch_panel_toward(n, 200), 19, "stretched to the far room")
	t.ok(page.move_card(later, n), "now LATER fits")
	t.ok(page.features["vine"].active, "the vine grows")
	t.ok(await _climb_to(t, page, n.position.y + 96), "up the vine (Nib at %s)" % page.player.position)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "along the ledge and out")
	await _free(t, page)


## 2.6 "Close Shave": swap the lever's room under the close-up's ring.
func test_page_6_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p06")
	var view: CloseUp = page.closeups["view"]
	var exited := _exits(page)
	t.eq(view.control(), null, "the ring is over the empty room")
	t.ok(page.swap_panels(page.panels["lever_room"], page.panels["empty"]), "swapped")
	t.eq(view.control(), page.controls["lever1"], "the lever is in the close-up")
	t.ok(view.click(view.center), "pulled")
	t.ok(page.features["bridge"].active, "the bridge comes down")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "across and out")
	await _free(t, page)


## 2.7 "Page Layout": slide the far room in for its word, then swap Nib's
## room next to the last door and give it OPEN.
func test_page_7_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p07")
	var a: ComicPanel = page.panels["a"]
	var door: Door = page.doors[0]
	var exited := _exits(page)
	t.eq(page.links.size(), 0, "nothing links yet")
	t.eq(page.move_panel_toward(page.panels["e"], Vector2i(416, 16)), 2, "the far room slid in")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "take", 300), "OPEN in reach")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "OPEN", "carrying OPEN")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return page.player_panel() == a and page.player.position.x < a.position.x + 150), "back into Nib's room")
	t.ok(page.swap_panels(a, page.panels["d"]), "Nib's room swapped before the door")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "swap", 600), "SHUT in reach")
	page.interaction.perform()
	await t.frames(5)
	t.ok(door.is_open, "the last door opens")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "out")
	await _free(t, page)


## 2.8 "The Border": the artist boxes Nib in; the box stretches.
func test_page_8_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch02_p08")
	var exited := _exits(page)
	EventBus.page_entered.emit("ch02_p08")
	await _wait(t, 200)
	t.eq(page.captions["artist"].text, "STAY IN|YOUR BOX.", "the artist draws Nib a box")
	t.ok(not await _walk_until(t, "move_right", func() -> bool: return exited[0], 240), "and it holds")
	t.eq(page.stretch_panel_toward(page.panels["box"], 296), 29, "the box stretched to the next room")
	await _wait(t, 200)
	t.eq(page.captions["artist"].text, "...FINE.|GO ON, THEN.", "the artist gives up")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "out of the box and on")
	await _free(t, page)
