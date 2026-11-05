extends RefCounted
## Phase 3 weight on the sandbox page, through real physics: crates weigh
## what their `mass` label says, pressure plates give under enough weight,
## and wired doors follow their plates (GDD §4.2).


func _build(t, state := {}, player := {}) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("sb_weight"), state, player)
	await t.frames(2)
	return page


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


func test_weights_are_data(t) -> void:
	t.eq(Crate.weight_for(""), 1.0, "a crate as drawn weighs one")
	t.eq(Crate.weight_for("HEAVY"), 2.0, "HEAVY")
	t.eq(Crate.weight_for("LIGHT"), 0.5, "LIGHT")
	t.eq(Crate.weight_for("UP"), 1.0, "motion words don't change weight")
	t.eq(Crate.heading_for("HEAVY"), Vector2i.DOWN, "a heavy crate falls")
	t.eq(Crate.heading_for("LIGHT"), Vector2i.DOWN, "a light crate falls too")


func test_plate_needs_enough_weight(t) -> void:
	var page: ComicPage = await _build(t)
	var b1: PlateButton = page.buttons["b1"]
	var c1: Crate = page.crates["c1"]
	var d1: Door = page.doors[0]
	page.player.position = Vector2(56, 168)
	await t.frames(5)
	t.ok(b1.load_on() == 1.0, "the crate rests on the plate (%s)" % b1.load_on())
	t.ok(not b1.pressed, "one crate isn't enough for a plate that needs two")
	t.ok(not d1.is_open, "the wired door stays shut")
	t.ok(c1.slot.accepts_word("HEAVY"), "crates take mass words")

	c1.slot.put("HEAVY")
	await t.frames(3)
	t.ok(b1.pressed, "a HEAVY crate presses it")
	t.ok(d1.powered and d1.is_open, "and holds the door open")

	c1.slot.take()
	await t.frames(3)
	t.ok(not b1.pressed, "taking HEAVY lets the plate up")
	t.ok(not d1.is_open, "and the door shuts")

	# Nib riding the crate adds Nib's weight to the crate's.
	page.player.position = c1.global_position + Vector2(16, 0)
	await t.frames(10)
	t.ok(c1.carries(page.player), "Nib stands on the crate")
	t.ok(b1.pressed, "crate plus Nib is two")
	await _free(t, page)


func test_plate_label_scales_what_it_needs(t) -> void:
	var page: ComicPage = await _build(t)
	var b1: PlateButton = page.buttons["b1"]
	page.player.position = Vector2(56, 168)
	await t.frames(3)
	b1.slot.put("LIGHT")
	await t.frames(2)
	t.eq(b1.threshold(), 1.0, "a LIGHT plate needs half")
	t.ok(b1.pressed, "so the crate alone presses it")
	b1.slot.take()
	b1.slot.put("HEAVY")
	await t.frames(2)
	t.eq(b1.threshold(), 4.0, "a HEAVY plate needs double")
	t.ok(not b1.pressed, "and the crate is no longer enough")
	t.ok(not b1.slot.accepts_word("UP"), "plates refuse motion words")
	await _free(t, page)


func test_light_crate_is_too_light(t) -> void:
	var page: ComicPage = await _build(t)
	var b2: PlateButton = page.buttons["b2"]
	var c2: Crate = page.crates["c2"]
	page.player.position = Vector2(56, 168)
	await t.frames(3)
	t.eq(b2.load_on(), 0.5, "a LIGHT crate weighs half")
	t.ok(not b2.pressed, "not enough for a plain plate")
	c2.slot.take()
	await t.frames(2)
	t.ok(b2.pressed, "as drawn it weighs one")

	# Nib alone presses a plain plate.
	c2.slot.put("UP")
	for i in 120:
		await t.root.get_tree().physics_frame
	t.ok(not b2.pressed, "the crate rose off the plate")
	page.player.position = b2.global_position + Vector2(16, 0)
	await t.frames(10)
	t.ok(b2.pressed, "Nib alone presses a plain plate")
	await _free(t, page)


func test_light_crate_drifts(t) -> void:
	var page: ComicPage = await _build(t)
	var c1: Crate = page.crates["c1"]
	var c2: Crate = page.crates["c2"]
	t.ok(c2.speed() < c1.speed(), "a LIGHT crate falls slower (%s < %s)" % [c2.speed(), c1.speed()])
	await _free(t, page)


func test_restored_plate_is_silent(t) -> void:
	# A saved HEAVY label on the crate restores the plate already pressed and
	# the door already open, without replaying events.
	var events := []
	var on_press := func(id: String) -> void: events.append(id)
	EventBus.button_pressed.connect(on_press)
	var page: ComicPage = await _build(t, {"slots": {"c1:label": "HEAVY"}})
	t.ok(page.buttons["b1"].pressed, "restored pressed")
	t.ok(page.doors[0].is_open, "restored open")
	t.eq(events, [], "no button event on restore")
	EventBus.button_pressed.disconnect(on_press)
	await _free(t, page)
