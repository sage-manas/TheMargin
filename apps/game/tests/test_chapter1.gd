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


## Walks and hops (a full hop every 24 frames) until `cond` holds. With
## `action` "", hops straight up.
func _hop_until(t, action: String, cond: Callable, max_frames := 600) -> bool:
	if action != "":
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
	if action != "":
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


## Walks toward page x `x` and stops within half a unit of it.
func _walk_to_x(t, page: ComicPage, x: float) -> bool:
	for attempt in 6:
		var d := x - page.player.position.x
		if absf(d) < 0.5:
			return true
		var action := "move_right" if d > 0 else "move_left"
		Input.action_press(action)
		for i in 300:
			await t.root.get_tree().physics_frame
			if (x - page.player.position.x) * signf(d) <= 0.5:
				break
		Input.action_release(action)
		await t.frames(20)
	return absf(x - page.player.position.x) < 2.0


## Hops straight up until Nib stands at page y `y` (a ledge or a top leaf).
func _climb_to(t, page: ComicPage, y: float, max_frames := 900) -> bool:
	return await _hop_until(t, "", func() -> bool: return page.player.is_on_floor() and page.player.position.y <= y + 0.5, max_frames)


## Page 1.3 "Later": LATER starts by the vine, so the ice in Nib's room is
## frozen. Moving the card melts the ice (and shrinks the vine); once Nib is
## through, moving it back grows the vine to the door on the ledge.
func test_page_3_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p03")
	var a: ComicPanel = page.panels["a"]
	var b: ComicPanel = page.panels["b"]
	var later: SceneCard = page.cards["later"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.ok(page.features["vine"].active and page.features["ice"].active, "the vine has grown; the ice is frozen")
	t.ok(not await _walk_until(t, "move_left", _in(page, "a"), 360), "the ice blocks the way")
	t.ok(page.move_card(later, b), "LATER to the cold room")
	t.ok(not page.features["ice"].active and not page.features["vine"].active, "the ice melts; the vine is a seed again")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return _in(page, "a").call() and page.player.position.x < a.position.x + 200), "through to the seed's room")
	t.ok(page.move_card(later, a), "LATER back")
	t.ok(page.features["vine"].active, "the vine grows")
	t.ok(await _walk_to_x(t, page, a.position.x + 112), "to the vine")
	t.ok(await _climb_to(t, page, a.position.y + 96), "up the leaves to the ledge (Nib at %s)" % page.player.position)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "out through the door")
	await _free(t, page)


## Without LATER, the seed is no help: the ledge is out of reach.
func test_page_3_needs_later(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p03", {"scenes": {"later": "b"}})
	var a: ComicPanel = page.panels["a"]
	page.player.position = a.position + Vector2(112, 312)
	page.player.velocity = Vector2.ZERO
	await t.frames(5)
	t.ok(not await _climb_to(t, page, a.position.y + 96, 300), "no vine, no way up")
	await _free(t, page)


## Page 1.4 "Close Up": the close-up's ring is over empty page until the
## lever's room is slid under it. Pulling the lever lifts the gate, and
## reaching the neighbour turns the page.
func test_page_4_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p04")
	var view: CloseUp = page.closeups["view"]
	var n: ComicPanel = page.panels["n"]
	var turned := [false]
	page.exit_requested.connect(func() -> void: turned[0] = true)
	t.eq(view.control(), null, "the close-up sees nothing yet")
	t.ok(not await _walk_until(t, "move_right", func() -> bool: return page.player.position.x > n.position.x + 30, 360), "the gate holds")
	t.eq(page.move_panel_toward(page.panels["h"], Vector2i(216, 16)), 25, "the lever's room slid under the ring")
	t.eq(view.control(), page.controls["lever1"], "the lever in the close-up")
	t.ok(view.click(view.center), "pulled")
	t.ok(not page.features["gate"].active, "the gate lifts")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return turned[0], 900), "to the neighbour, and the page turns")
	await _free(t, page)


## Page 1.5 "That Night": two cards, three rooms. LATER grows the vine in
## the first stairwell; THAT NIGHT lights glow steps in the second but wakes
## the neighbour, who blocks the door until it is night in their room again.
func test_page_5_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p05")
	var s1: ComicPanel = page.panels["s1"]
	var s2: ComicPanel = page.panels["s2"]
	var m: ComicPanel = page.panels["m"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.ok(page.npcs["asleep"].visible, "the neighbour starts asleep")
	t.ok(page.move_card(page.cards["later"], s1), "LATER to the first stairwell")
	t.ok(await _walk_to_x(t, page, s1.position.x + 112), "to the vine")
	t.ok(await _climb_to(t, page, s1.position.y + 36), "up the vine (Nib at %s)" % page.player.position)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "s2").call() and page.player.position.x > s2.position.x + 30), "onto the landing")
	t.ok(page.move_card(page.cards["night"], s2), "THAT NIGHT to the second stairwell")
	t.ok(page.features["steps"].active and page.npcs["awake"].visible, "glow steps; the neighbour wakes")
	t.ok(await _hop_until(t, "move_right", func() -> bool: return page.player.is_on_floor() and page.player.position.y <= s2.position.y + 114.5, 900), "up the glow steps (Nib at %s)" % page.player.position)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "m").call() and page.player.position.x > m.position.x + 60), "into the neighbour's room")
	t.ok(not await _walk_until(t, "move_right", func() -> bool: return exited[0], 180), "the neighbour blocks the door")
	t.ok(page.move_card(page.cards["night"], m), "THAT NIGHT back to the neighbour")
	t.ok(page.npcs["asleep"].visible and not page.npcs["awake"].visible, "asleep again")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "past them and out")
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


## Turns a combination dial through its close-up to `code`, as the reader's
## hand clicks it: the top half of a wheel turns it up, the bottom down.
func _dial(view: CloseUp, code: String) -> void:
	var ctl := view.control()
	var n := ctl.digits.size()
	for i in n:
		var c := view.center + Vector2(-n * 6.0 + i * 12.0 + 6.0, 0)
		while ctl.digits[i] != int(code[i]):
			var up := (int(code[i]) - ctl.digits[i] + 10) % 10 <= 5
			view.click(c + Vector2(0, -4 if up else 8))


## Page 1.6 "The Empty Room": lower N to meet A. The neighbour is gone, but
## their note glows at night; its code opens the door through the close-up.
## The fallen bubble is still the step up to the ledge.
func test_page_6_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p06")
	var n: ComicPanel = page.panels["n"]
	var view: CloseUp = page.closeups["lock_view"]
	var door: Door = page.doors[0]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.eq(page.links.size(), 0, "N starts too high")
	t.eq(view.control(), null, "the lock is above the close-up's ring")
	t.eq(page.move_panel_toward(n, Vector2i(224, 40)), 3, "N lowered to meet A")
	t.eq(view.control(), page.controls["lock"], "now the close-up sees the lock")
	t.ok(not page.features["note"].active, "by day there is no note")
	t.ok(not page.doors[0].slot.accepts_word("OPEN"), "and no word opens this door: only its lock")
	t.ok(page.move_card(page.cards["night"], n), "THAT NIGHT to the empty room")
	t.ok(page.features["note"].active, "the note glows: FOR NIB: 3 0 8")
	_dial(view, "308")
	t.eq(page.controls["lock"].value(), "308", "dialled")
	await t.frames(5)
	t.ok(door.is_open, "the door opens")

	var bubble_top := n.position.y + 104
	t.ok(await _hop_until(t, "move_right", func() -> bool: return _in(page, "n").call() and page.player.is_on_floor() and absf(page.player.position.y - bubble_top) < 0.5), "standing on the fallen bubble")
	t.ok(await _hop_until(t, "move_right", func() -> bool: return exited[0], 600), "up to the ledge and out")
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


## Page 1.7 "The Long Night": every tool at once. Take OPEN from the
## caption, slide V so its lever is under the close-up and lower the bridge,
## cross while LATER keeps the ice melted, then move LATER to grow the vine,
## climb to the door and swap OPEN for SHUT.
func test_page_7_solution(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p07")
	var r: ComicPanel = page.panels["r"]
	var view: CloseUp = page.closeups["view"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "take", 120), "OPEN in reach")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "OPEN", "carrying OPEN")
	t.eq(view.control(), null, "the close-up sees nothing yet")
	t.eq(page.move_panel_toward(page.panels["v"], Vector2i(424, 224)), 7, "V slid down")
	t.ok(view.click(view.center), "the lever pulled in the close-up")
	t.ok(page.features["bridge"].active, "the bridge comes down")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return _in(page, "r").call() and page.player.position.x > r.position.x + 30, 900), "across the bridge, past the melted ice")
	t.ok(page.move_card(page.cards["later"], r), "LATER to the last room")
	t.ok(page.features["vine"].active and page.features["ice"].active, "the vine grows; the ice freezes behind")
	t.ok(await _walk_to_x(t, page, r.position.x + 88), "to the vine")
	t.ok(await _climb_to(t, page, r.position.y + 56), "up to the ledge (Nib at %s)" % page.player.position)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.interaction.verb == "swap", 300), "the door's SHUT in reach")
	page.interaction.perform()
	t.eq(page.interaction.carrying, "SHUT", "OPEN on the door")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "out")
	await _free(t, page)


## Moving LATER on too soon freezes the ice in the middle room again.
func test_page_7_order(t) -> void:
	var page: ComicPage = await _build(t, "ch01_p07", {"controls": {"lever1": true}, "scenes": {"later": "r"}})
	var p: ComicPanel = page.panels["p"]
	t.ok(page.features["ice"].active and page.features["bridge"].active, "bridge down, ice frozen")
	t.ok(not await _walk_until(t, "move_right", func() -> bool: return page.player.position.x > p.position.x + 172, 600), "the ice stops Nib")
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
