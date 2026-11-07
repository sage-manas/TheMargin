extends RefCounted
## Chapter 1 pages after the prototype (GDD §6), each solved through real
## physics and the same public APIs the reader's hand and Nib use.


func _build(t, id: String, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def(id), state, player)
	await t.frames(2)
	return page


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


## Walks and hops (a full hop every 24 frames) until `cond` holds.
func _hop_until(t, action: String, cond: Callable, max_frames := 600) -> bool:
	Input.action_press(action)
	var ok := false
	for i in max_frames:
		if i % 24 == 0:
			Input.action_press("jump")
		elif i % 24 == 18:
			Input.action_release("jump")
		await t.root.get_tree().physics_frame
		if cond.call():
			ok = true
			break
	Input.action_release(action)
	Input.action_release("jump")
	await t.frames(10)
	return ok


func _in(page: ComicPage, panel_id: String) -> Callable:
	return func() -> bool: return page.player_panel() == page.panels[panel_id]


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


func test_page_2_turns_to_page_3(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p02")
	var turned := [false]
	page.exit_requested.connect(func() -> void: turned[0] = true)
	EventBus.page_entered.emit("ch01_p02")
	for i in 900:
		await t.root.get_tree().physics_frame
		if turned[0]:
			break
	t.ok(turned[0], "the artist's page turns itself")
	t.eq(page.captions["artist"].text, "WHO MOVED|MY PANELS?", "after the artist wrote")
	t.eq(page.def["next"], "ch01_p03", "on to page 3")
	await _free(t, page)


## Page 1.3: slide H to A, ride H across, raise V to meet it, ride V down.
func test_page_3_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p03")
	var h: ComicPanel = page.panels["h"]
	var v: ComicPanel = page.panels["v"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.eq(page.links.size(), 1, "only the way out (V-E) is linked at the start")

	# A's border holds until H comes over.
	await _walk_until(t, "move_right", func() -> bool: return false, 150)
	t.eq(page.player_panel(), page.panels["a"], "sealed in A")
	t.eq(page.move_panel_toward(h, Vector2i(184, 16)), 14, "H slides left along its track")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "a" and l.b == "h"), "A-H linked")

	# Into H, then ride it across with Nib inside.
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "h").call() and page.player.position.x > 260), "walked into H")
	var before := page.player.position
	t.eq(page.move_panel_toward(h, Vector2i(296, 16)), 14, "rode H back across")
	t.eq(page.player.position - before, Vector2(112, 0), "Nib moved with H")

	# V is down at the way out; raise it to meet H. Nib isn't in it.
	t.eq(page.move_panel_toward(v, Vector2i(464, 16)), 22, "V rises to meet H")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "h" and l.b == "v"), "H-V linked")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "v").call() and page.player.position.x > 500), "walked into V")

	# Ride V down until it links with E again, then walk out through the door.
	t.eq(page.move_panel_toward(v, Vector2i(464, 192)), 22, "rode V down")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "e" and l.b == "v"), "V-E linked")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return exited[0], 900), "out through the door (Nib at %s)" % page.player.position)
	await _free(t, page)


## The order matters: riding H across before raising V leaves Nib stranded
## in H until V comes up, and V can't carry Nib up from E (they're never in it).
func test_page_3_order(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p03")
	var h: ComicPanel = page.panels["h"]
	var v: ComicPanel = page.panels["v"]
	t.eq(page.move_panel_toward(v, Vector2i(464, 16)), 22, "V can rise first")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "h" and l.b == "v"), "H-V linked with H at its start")
	t.eq(page.move_panel_toward(h, Vector2i(184, 16)), 14, "but H must still fetch Nib")
	t.ok(not page.links.any(func(l: Dictionary) -> bool: return l.b == "v"), "which leaves V linked to nothing")
	await _free(t, page)


## Page 1.4: HEAVY pins the middle room. Taking it frees the room, and the
## same word is what the box needs to press the plate.
func test_page_4_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p04")
	var l: ComicPanel = page.panels["l"]
	var door: Door = page.doors[0]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.ok(l.is_pinned(), "HEAVY pins the room")
	t.eq(page.move_panel_toward(l, Vector2i(200, 200)), 0, "a heavy room won't slide")

	# Into L, up to the reach point under its caption, and take HEAVY.
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "take"), "HEAVY in reach")
	t.eq(page.player_panel(), l, "from inside the heavy room")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "HEAVY", "carrying HEAVY")
	t.ok(not l.is_pinned(), "the room is free")

	# Ride L down; it links to both rooms below.
	var before := page.player.position
	t.eq(page.move_panel_toward(l, Vector2i(200, 200)), 23, "rode L down")
	t.eq(page.player.position - before, Vector2(0, 184), "Nib came along")
	t.eq(page.links.size(), 2, "L-B and L-X linked")

	# The door won't open for Nib: the plate is in B, under the box.
	t.ok(not door.is_open, "door shut while the plate is up")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return page.interaction.verb == "place" and page.interaction.target.id == "box4:label", 600), "box label in reach")
	page.interaction.perform()
	await t.frames(10)
	t.ok(page.buttons["plate4"].pressed, "a HEAVY box presses the plate")
	t.ok(door.is_open, "and the wired door opens")

	# Back through L to the door.
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "out through the door (Nib at %s)" % page.player.position)
	await _free(t, page)


## Nib can't stand on the box (the shelf is too low), so only HEAVY presses it.
func test_page_4_box_needs_heavy(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p04")
	var plate: PlateButton = page.buttons["plate4"]
	t.ok(not plate.pressed, "a plain box is too light")
	page.player.position = page.panels["b"].global_position + Vector2(80, 160)
	page.player.velocity = Vector2.ZERO
	await t.frames(5)
	var pressed := false
	var on_box := false
	var top := page.player.position.y
	Input.action_press("move_left")
	for i in 180:
		if i % 20 == 0:
			Input.action_press("jump")
		elif i % 20 == 6:
			Input.action_release("jump")
		await t.root.get_tree().physics_frame
		pressed = pressed or plate.pressed
		on_box = on_box or page.crates["box4"].carries(page.player)
		top = minf(top, page.player.position.y)
	Input.action_release("move_left")
	Input.action_release("jump")
	t.ok(top < page.panels["b"].global_position.y + 160 - 16, "Nib really hopped")
	t.ok(not on_box, "hopping at the nook never lands Nib on the box")
	t.ok(not pressed, "so the plate never gives")
	await _free(t, page)


## Page 1.5: lower K2 to K1, ride the crate UP onto the ledge, raise K2 to K3.
func test_page_5_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p05")
	var k2: ComicPanel = page.panels["k2"]
	var box: Crate = page.crates["box5"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "k2" and l.b == "k3"), "the top of the stairs is linked at the start")

	# Take UP out of K1's caption.
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "take"), "UP in reach")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "UP", "carrying UP")

	# Lower K2 to K1 and walk in, up onto the crate.
	t.eq(page.move_panel_toward(k2, Vector2i(200, 144)), 16, "K2 lowered")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "k1" and l.b == "k2"), "K1-K2 linked")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "k2").call() and page.player.position.x >= k2.position.x + 110), "walked into K2")
	Input.action_press("jump")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return box.carries(page.player), 120), "hopped onto the crate")
	Input.action_release("jump")
	await t.frames(10)

	# UP from on top: the crate rises until Nib's head meets the beam.
	t.eq(page.interaction.verb, "place", "the crate's label is in reach from on top")
	page.interaction.perform()
	for i in 300:
		await t.root.get_tree().physics_frame
		if not box.moving and i > 10:
			break
	t.ok(box.carries(page.player), "Nib rode it up")
	t.ok(page.player.position.y - k2.position.y < 64.0, "above the ledge (feet at %s)" % (page.player.position.y - k2.position.y))

	# Step onto the ledge, then raise K2 to the top of the stairs.
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.player.position.x >= k2.position.x + 176 and page.player.is_on_floor(), 120), "on the ledge")
	t.eq(page.move_panel_toward(k2, Vector2i(200, 16)), 16, "K2 raised with Nib inside")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "k2" and l.b == "k3"), "K2-K3 linked")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "out through the door (Nib at %s)" % page.player.position)
	await _free(t, page)


## Without UP, the ledge is out of reach even from the crate.
func test_page_5_ledge_needs_up(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p05")
	var k2: ComicPanel = page.panels["k2"]
	page.move_panel_toward(k2, Vector2i(200, 144))
	page.player.position = k2.global_position + Vector2(144, 160)
	page.player.velocity = Vector2.ZERO
	await t.frames(10)
	t.ok(page.crates["box5"].carries(page.player), "standing on the plain crate")
	var top := page.player.position.y
	Input.action_press("jump")
	for i in 40:
		await t.root.get_tree().physics_frame
		top = minf(top, page.player.position.y)
	Input.action_release("jump")
	t.ok(top - k2.position.y > 64.0 + Player.SIZE.y, "a hop from the crate stays below the ledge (peak feet %s)" % (top - k2.position.y))
	await _free(t, page)


## The chapter runs 1.1 → 1.8, and the end card follows 1.8.
func test_chapter_runs_in_order(t) -> void:
	var id := "ch01_p01"
	var seen := []
	while id != "" and not seen.has(id):
		seen.append(id)
		id = ComicPage.load_def(id).get("next", "")
	t.eq(seen.size(), 8, "eight pages")
	t.eq(seen[-1], "ch01_p08", "ending on the finale")
	t.eq(id, "", "which leads to the end card")


## Page 1.6: lower N to meet A, climb onto the fallen bubble, take OPEN out
## of what the neighbour used to say, and open the door on the ledge.
func test_page_6_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p06")
	var n: ComicPanel = page.panels["n"]
	var door: Door = page.doors[0]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.eq(page.links.size(), 0, "N starts too high")
	t.eq(page.move_panel_toward(n, Vector2i(224, 40)), 3, "N lowered to meet A")
	t.eq(page.links.size(), 1, "A-N linked")

	# Into N, then up onto the bubble lying on the floor.
	var bubble_top := n.position.y + 104
	t.ok(await _hop_until(t, "move_right", func() -> bool: return _in(page, "n").call() and page.player.is_on_floor() and absf(page.player.position.y - bubble_top) < 0.5), "standing on the fallen bubble")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "take", 120), "OPEN in reach from on top")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "OPEN", "carrying OPEN")
	t.ok(absf(page.player.position.y - bubble_top) < 0.5, "the bubble didn't move under Nib")

	# Up onto the ledge and swap OPEN for SHUT.
	t.ok(await _hop_until(t, "move_right", func() -> bool: return page.interaction.verb == "swap", 300), "the door's label in reach from the ledge")
	page.interaction.perform()
	await t.frames(5)
	t.ok(door.is_open, "the door opens")
	t.eq(page.interaction.carrying, "SHUT", "carrying SHUT")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 300), "out through the door (Nib at %s)" % page.player.position)
	await _free(t, page)


## The ledge is one hop too high from the floor, and the bubble's word can't
## be reached from the floor or the ledge: only from standing on it.
func test_page_6_bubble_is_the_step(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p06", {"panels": {"n": [224, 40]}})
	var n: ComicPanel = page.panels["n"]
	page.player.position = n.global_position + Vector2(150, 128)
	page.player.velocity = Vector2.ZERO
	await t.frames(5)
	t.eq(page.interaction.verb, "", "the bubble's word is out of reach from the floor")
	var top := page.player.position.y
	Input.action_press("jump")
	for i in 40:
		await t.root.get_tree().physics_frame
		top = minf(top, page.player.position.y)
	Input.action_release("jump")
	t.ok(n.global_position.y + 128 - top < 32.0, "a hop from the floor (%s px) stays below the ledge" % (n.global_position.y + 128 - top))
	page.player.position = n.global_position + Vector2(344, 96)
	page.player.velocity = Vector2.ZERO
	await t.frames(5)
	t.ok(page.interaction.target == null or page.interaction.target.id != "fallen:0", "nor from the ledge")
	await _free(t, page)


## Page 1.7: take OPEN from the door behind, ride H across, lend OPEN to
## R's caption to free it, clear V out of R's way, ride R down, take OPEN
## back, and carry it to the last door.
func test_page_7_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p07")
	var h: ComicPanel = page.panels["h"]
	var r: ComicPanel = page.panels["r"]
	var v: ComicPanel = page.panels["v"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)

	t.ok(await _walk_until(t, "move_left", func() -> bool: return page.interaction.verb == "take"), "the door behind in reach")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "OPEN", "carrying OPEN")
	t.ok(not page.doors[0].is_open, "the door behind shuts")

	t.eq(page.move_panel_toward(h, Vector2i(136, 16)), 10, "H fetches Nib")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "h").call() and page.player.position.x > h.position.x + 40), "walked into H")
	t.eq(page.move_panel_toward(h, Vector2i(216, 16)), 10, "rode H across")
	t.ok(r.is_pinned(), "STOP holds R")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "swap"), "R's caption in reach")
	t.eq(page.player_panel(), r, "from inside R")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "STOP", "lent OPEN, carrying STOP")
	t.ok(not r.is_pinned(), "R is free")

	# V sits under R's shaft: R stops a gutter above it until V moves over.
	t.eq(page.move_panel_toward(r, Vector2i(320, 200)), 4, "R stops above V")
	t.eq(page.move_panel_toward(v, Vector2i(432, 200)), 14, "V slides over to the far side")
	t.eq(page.move_panel_toward(r, Vector2i(320, 200)), 19, "R goes the rest of the way down")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "r" and l.b == "v"), "R-V linked")
	t.ok(page.links.any(func(l: Dictionary) -> bool: return l.a == "v" and l.b == "e"), "V-E linked")
	t.eq(page.player_panel(), r, "Nib rode R down")

	await t.frames(2)
	t.eq(page.interaction.verb, "swap", "OPEN can come back out")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "OPEN", "carrying OPEN again")
	t.ok(r.is_pinned(), "and STOP holds R where it is now")

	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "swap" and page.interaction.target.id == "door7:label", 900), "the last door in reach")
	page.interaction.perform()
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "out through the door (Nib at %s)" % page.player.position)
	await _free(t, page)


## Saved positions are restored together: R saved at the bottom must not be
## refused because V started under it.
func test_page_7_restores_together(t) -> void:
	var state := {"panels": {"h": [216, 16], "r": [320, 200], "v": [432, 200]}, "slots": {"door_back:label": null, "cap_r:0": "STOP"}}
	var page: ComicPage = await _build(t, "ch01_p07", state, {"position": [372, 328], "carrying": "OPEN"})
	t.eq(Vector2i(page.panels["r"].position), Vector2i(320, 200), "R restored at the bottom")
	t.eq(Vector2i(page.panels["v"].position), Vector2i(432, 200), "V restored on the far side")
	t.eq(page.player_panel(), page.panels["r"], "Nib restored in R")
	await _free(t, page)
	# Positions that clash with each other all start over.
	page = await _build(t, "ch01_p07", {"panels": {"r": [320, 200]}})
	t.eq(Vector2i(page.panels["r"].position), Vector2i(320, 16), "R can't be restored onto V")
	await _free(t, page)


## Page 1.8: walk into the next room and the artist rubs out the first one.
## The space it leaves lets L rise to meet P2 and carry Nib down to the exit.
func test_page_8_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p08")
	var p1: ComicPanel = page.panels["p1"]
	var l: ComicPanel = page.panels["l"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.eq(page.move_panel_toward(l, Vector2i(16, 16)), 4, "the little room stops L a gutter below it")

	t.ok(await _walk_until(t, "move_right", _in(page, "p2")), "into the next room")
	await t.frames(2)
	t.ok(p1.erased, "the artist rubs out the little room")
	t.ok(not page.links.any(func(l2: Dictionary) -> bool: return l2.a == "p1" or l2.b == "p1"), "its link is gone")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return false, 90) == false and page.player_panel() == page.panels["p2"], "the way back is sealed")
	for i in 240:
		await t.root.get_tree().physics_frame
	t.eq(page.captions["artist8"].text, "FROM THE|TOP.", "the artist starts over")

	t.eq(page.move_panel_toward(l, Vector2i(16, 16)), 19, "L rises into the space")
	t.ok(page.links.any(func(l2: Dictionary) -> bool: return l2.a == "l" and l2.b == "p2"), "L-P2 linked")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return _in(page, "l").call() and page.player.position.x < l.position.x + 160), "walked into L")
	t.eq(page.move_panel_toward(l, Vector2i(16, 200)), 23, "rode L down")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 900), "out through the door (Nib at %s)" % page.player.position)
	await _free(t, page)


## The erasure waits for Nib to be wholly out of the panel.
func test_page_8_erasure_waits_for_nib(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p08")
	page.erase_panel("p1")
	await t.frames(5)
	t.ok(not page.panels["p1"].erased, "not while Nib is inside")
	page.player.position = page.panels["p2"].global_position + Vector2(5, 128)
	page.player.velocity = Vector2.ZERO
	await t.frames(3)
	t.ok(page.panels["p1"].erased, "once Nib is next door")
	t.ok(page.player.position.x >= page.panels["p2"].position.x + PageConst.BORDER + Player.SIZE.x / 2.0, "Nib kept clear of the closed border")
	await _free(t, page)


## A saved erasure is re-applied at once: the room stays gone, L may rest in
## its space, and Nib never starts in it.
func test_page_8_restores_erasure(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p08", {"fired": ["from_the_top"], "panels": {"l": [16, 16]}})
	t.ok(page.panels["p1"].erased, "the little room stays rubbed out")
	t.eq(Vector2i(page.panels["l"].position), Vector2i(16, 16), "L restored in its space")
	t.eq(page.player_panel(), page.panels["p2"], "Nib starts next door")
	t.eq(page.captions["cap2"].text, "AND THEN,|THERE WASN'T.", "the narrator's rewrite stays")
	await _free(t, page)
