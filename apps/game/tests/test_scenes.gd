extends RefCounted
## Scene captions (GDD §4.7) and close-ups (GDD §4.8), on the sandbox pages
## sb_scenes and sb_closeups, through real physics and the same calls the
## reader's hand makes.


func _build(t, id: String, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def(id), state, player)
	await t.frames(2)
	return page


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


## Holds `actions` (none, to stand still) and hops every 24 frames until `cond`.
func _hop_until(t, actions: Array, cond: Callable, max_frames := 600) -> bool:
	for a: String in actions:
		Input.action_press(a)
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
	for a: String in actions:
		Input.action_release(a)
	Input.action_release("jump")
	await t.frames(10)
	return ok


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


func test_conditions(t) -> void:
	t.ok(Conditions.met("", "", {}), "no condition always holds")
	t.ok(Conditions.met("later", "later", {}), "a scene")
	t.ok(not Conditions.met("later", "night", {}), "another scene")
	t.ok(Conditions.met("!night", "", {}), "negated")
	t.ok(Conditions.met("lever1", "", {"lever1": true}), "a switch")
	t.ok(not Conditions.met("lever1 & night", "", {"lever1": true}), "both must hold")
	t.eq(Conditions.terms("!a & b"), ["a", "b"], "terms")


## The whole LATER loop: the ice blocks the way while LATER is next door;
## moving the card melts it (and the vine shrinks); moving it back grows the
## vine, which Nib climbs to the exit.
func test_later_card_loop(t) -> void:
	var page: ComicPage = await _build(t, "sb_scenes")
	var later: SceneCard = page.cards["later"]
	var night: SceneCard = page.cards["night"]
	var a: ComicPanel = page.panels["a"]
	var b: ComicPanel = page.panels["b"]
	var exited := [false]
	page.exit_requested.connect(func() -> void: exited[0] = true)
	t.eq(page.scene_of(a), "later", "A starts LATER")
	t.ok(page.features["vine"].active and page.features["ice"].active, "vine grown, ice frozen")

	t.ok(not await _walk_until(t, "move_left", func() -> bool: return page.player_panel() == a, 240), "the ice blocks the way")
	t.ok(not page.move_card(later, b), "B already holds a card")
	t.ok(page.move_card(night, page.panels["n"]), "THAT NIGHT moves to the bottom room")
	t.ok(page.move_card(later, b), "LATER moves to B")
	t.ok(not page.features["ice"].active and not page.features["vine"].active, "the ice melted; the vine is a sprout again")
	t.ok(await _walk_until(t, "move_left", func() -> bool: return page.player_panel() == a and page.player.position.x < a.position.x + 162), "through to A")

	t.ok(page.move_card(later, a), "LATER back to A")
	t.ok(page.features["vine"].active and page.features["ice"].active, "the vine grows; the ice freezes behind Nib")
	t.ok(await _walk_until(t, "move_right", func() -> bool: return page.player.position.x >= a.position.x + 160), "to the foot of the vine")
	t.ok(await _hop_until(t, [], func() -> bool: return page.player.position.y <= a.position.y + 48 + 1 and page.player.is_on_floor(), 900), "up the leaves (Nib at %s)" % page.player.position)
	t.ok(await _walk_until(t, "move_right", func() -> bool: return exited[0], 600), "along the ledge and out")
	await _free(t, page)


## A card won't land if it would grow something where Nib stands.
func test_card_refused_when_blocked(t) -> void:
	var page: ComicPage = await _build(t, "sb_scenes", {"scenes": {"later": "b", "night": "n"}})
	t.ok(not page.features["ice"].active, "LATER is in B: no ice")
	var b: ComicPanel = page.panels["b"]
	page.player.position = b.position + Vector2(20, 192)
	page.player.velocity = Vector2.ZERO
	await t.frames(3)
	t.ok(not page.move_card(page.cards["later"], page.panels["a"]), "refused: the ice would freeze around Nib")
	t.eq(page.cards["later"].panel, b, "the card stays")
	t.ok(not page.features["ice"].active, "nothing changed")
	await _free(t, page)


## Night: glow writing and steps appear, the neighbour goes to bed and stops
## blocking the way; by day they stand in it.
func test_night(t) -> void:
	var page: ComicPage = await _build(t, "sb_scenes")
	var n: ComicPanel = page.panels["n"]
	t.ok(page.npcs["awake"].visible and not page.npcs["asleep"].visible, "by day the neighbour is up")
	t.ok(not page.features["steps"].active and not page.features["code"].active, "no glow by day")
	t.ok(page.move_card(page.cards["night"], n), "THAT NIGHT to the bottom room")
	t.eq(n.scene, "night", "the room is night")
	t.ok(not page.npcs["awake"].visible and page.npcs["asleep"].visible, "the neighbour went to bed")
	t.ok(page.features["steps"].active and page.features["code"].active, "glow paint shows")
	await _free(t, page)


func test_scene_state_round_trip(t) -> void:
	var page: ComicPage = await _build(t, "sb_scenes")
	page.move_card(page.cards["night"], page.panels["n"])
	page.move_card(page.cards["later"], page.panels["b"])
	var st := page.capture_state()
	t.eq(st["scenes"], {"later": "b", "night": "n"}, "cards saved by panel")
	await _free(t, page)
	page = await _build(t, "sb_scenes", st)
	t.eq(page.scene_of(page.panels["b"]), "later", "B is LATER again")
	t.ok(not page.features["ice"].active and page.npcs["asleep"].visible, "and everything follows")
	await _free(t, page)
	# A save that puts two cards on one panel, or one on a missing panel, is ignored.
	page = await _build(t, "sb_scenes", {"scenes": {"later": "b"}})
	t.eq(page.cards["later"].panel, page.panels["a"], "two cards on one panel: all start over")
	await _free(t, page)
	page = await _build(t, "sb_scenes", {"scenes": {"later": "nowhere", "night": "n"}})
	t.eq(page.cards["later"].panel, page.panels["a"], "a missing panel keeps the card where it starts")
	t.eq(page.cards["night"].panel, page.panels["n"], "the other card is still restored")
	await _free(t, page)


## The close-up looks at the page: it sees the lever only once its panel is
## slid under the ring. Pulling it lifts the gate.
func test_closeup_lever(t) -> void:
	var page: ComicPage = await _build(t, "sb_closeups")
	var view: CloseUp = page.closeups["lever_view"]
	var h: ComicPanel = page.panels["h"]
	var r: ComicPanel = page.panels["r"]
	t.eq(view.control(), null, "nothing under the ring yet")
	t.ok(not view.click(view.center), "so nothing to work")
	t.ok(page.features["gate"].active, "the gate is down")
	var past_gate := func() -> bool: return page.player.position.x > r.position.x + 40
	t.ok(not await _walk_until(t, "move_right", past_gate, 360), "it blocks the way")

	page.move_panel_toward(h, Vector2i(216, 16))
	await t.frames(2)
	t.eq(view.control(), page.controls["lever1"], "the lever is under the ring")
	t.ok(view.click(view.center), "pulled in the close-up")
	t.ok(page.controls["lever1"].is_on(), "the lever is on")
	t.ok(not page.features["gate"].active, "the gate is up")
	t.ok(await _walk_until(t, "move_right", past_gate), "through")
	page.move_panel_toward(h, Vector2i(16, 16))
	await t.frames(2)
	t.eq(view.control(), null, "slid away, the close-up sees nothing")
	t.ok(page.controls["lever1"].is_on(), "but the lever stays where it was put")
	await _free(t, page)


## A dial is a switch while it shows its code; a door can be wired to it.
func test_closeup_dial(t) -> void:
	var page: ComicPage = await _build(t, "sb_closeups", {"controls": {"lever1": true}})
	var view: CloseUp = page.closeups["dial_view"]
	var dial: PageControl = page.controls["safe"]
	var door: Door = page.doors[0]
	t.eq(view.control(), dial, "the dial is in view")
	t.ok(not door.is_open, "the door is shut")
	# Wheels are 12 units wide around the centre; the top half turns up.
	var wheel := func(i: int) -> Vector2: return view.center + Vector2(-18.0 + i * 12.0 + 6.0, -4.0)
	for i in 4:
		view.click(wheel.call(0))
	view.click(wheel.call(1))
	for i in 3:
		view.click(wheel.call(2) + Vector2(0, 8))
	t.eq(dial.value(), "417", "turned to 4, 1, 7")
	t.ok(dial.is_on() and door.powered, "the code opens the wired door")
	var st := page.capture_state()
	t.eq(st["controls"], {"lever1": true, "safe": "417"}, "controls saved")
	await _free(t, page)
	page = await _build(t, "sb_closeups", {"controls": {"lever1": true, "safe": "41x"}})
	t.eq(page.controls["safe"].value(), "000", "a malformed dial in a save is ignored")
	await _free(t, page)
