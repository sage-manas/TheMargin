extends RefCounted
## Phase 3 ink on the sandbox page, through real physics: drops fill Nib's
## hat, ink traces only existing pencil, a traced sketch is solid and
## permanent, and the hat holds only so much (GDD §4.4).


func _build(t, state := {}, found := []) -> ComicPage:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("sb_ink"), state, {}, found)
	await t.frames(2)
	return page


func _free(t, page: ComicPage) -> void:
	page.queue_free()
	await t.frames(1)


## Puts Nib on a floor line of a panel at a panel-local x and lets it settle.
func _stand(t, page: ComicPage, panel: String, x: float, floor_y := 152.0) -> void:
	page.player.position = page.panels[panel].position + Vector2(x, floor_y)
	page.player.velocity = Vector2.ZERO
	await t.frames(4)
	for tool in page.tools:
		tool._refresh_target()


func test_verbs(t) -> void:
	t.eq(PlayerInk.verb_for(true, 1, 1, false), "trace", "ink traces pencil")
	t.eq(PlayerInk.verb_for(true, 2, 1, false), "short", "not without enough ink")
	t.eq(PlayerInk.verb_for(false, 1, 3, false), "smudged", "nothing left to trace on a smudge")
	t.eq(PlayerInk.verb_for(true, 1, 1, true), "blocked", "not around Nib or a crate")


func test_faint_pencil_is_only_a_plan(t) -> void:
	var page: ComicPage = await _build(t)
	var f1: Sketch = page.sketches["f1"]
	t.ok(f1.drawn and not f1.is_solid(), "a faint sketch is drawn but not solid")
	t.ok(page.sketches["p1"].is_solid(), "ordinary pencil is solid")
	page.player.position = f1.global_position + Vector2(20, 0)
	await t.frames(20)
	t.ok(page.player.global_position.y > f1.global_position.y + 10, "Nib falls through it")
	t.ok(page.ink_tool.target == null, "no ink yet, no prompt")
	await _free(t, page)


func test_collect_and_trace(t) -> void:
	var collected := []
	var on_collect := func(id: String) -> void: collected.append(id)
	EventBus.ink_collected.connect(on_collect)
	var page: ComicPage = await _build(t)
	var f1: Sketch = page.sketches["f1"]
	await _stand(t, page, "i1", 48)
	t.ok(page.has_ink(), "the first drop is the ability to trace")
	t.eq(page.ink(), 1, "one drop in the hat")
	t.eq(collected, ["drop"], "ink_collected fired")

	await _stand(t, page, "i1", 80)
	t.eq(page.ink(), 1, "the inkwell's two drops don't fit")
	t.ok(page.ink_drops.has("well") and page.ink_drops["well"].refused, "so it stays and says so")

	await _stand(t, page, "i1", 130)
	t.eq(page.ink_tool.target, f1, "the faint step is in reach")
	t.eq(page.ink_tool.verb, "trace", "and can be traced")
	t.ok(page.ink_tool.perform(), "trace")
	t.ok(f1.inked and f1.is_solid(), "it is ink now, and solid")
	t.eq(page.ink(), 0, "spending its drop")
	await t.frames(2)
	page.player.position = f1.global_position + Vector2(20, 0)
	await t.frames(20)
	t.ok(absf(page.player.global_position.y - f1.global_position.y) < 1.0, "Nib stands on it")

	await _stand(t, page, "i1", 80)
	t.eq(page.ink(), 2, "now the inkwell fits")
	t.eq(collected, ["drop", "well"], "both collected")
	EventBus.ink_collected.disconnect(on_collect)
	await _free(t, page)


func test_ink_is_forever(t) -> void:
	var page: ComicPage = await _build(t, {"sketches": {"f1": "inked"}, "collected": ["drop", "well"]}, ["ink", "eraser"])
	var f1: Sketch = page.sketches["f1"]
	var f2: Sketch = page.sketches["f2"]
	t.eq(page.ink(), 2, "three drops collected, one spent")
	await _stand(t, page, "i1", 130)
	t.ok(page.eraser.target != f1, "the eraser never targets ink")
	t.ok(page.ink_tool.target != f1, "and ink isn't traced twice")

	# Faint pencil is still pencil: it rubs out, and then there's nothing to trace.
	await _stand(t, page, "i1", 150, 132)
	t.eq(page.eraser.target, f2, "the eraser reaches the faint step")
	t.ok(page.eraser.perform(), "and rubs it out")
	page.ink_tool._refresh_target()
	t.eq(page.ink_tool.target, f2, "ink still points at the smudge")
	t.eq(page.ink_tool.verb, "smudged", "but there is nothing to trace")
	t.eq(page.ink_tool._prompts_below(), 1, "its prompt stacks above the eraser's")
	await _free(t, page)


func test_trace_refusals(t) -> void:
	var page: ComicPage = await _build(t, {}, ["ink"])
	var f1: Sketch = page.sketches["f1"]
	await _stand(t, page, "i1", 130)
	t.eq(page.ink_tool.verb, "short", "an empty hat can't trace")
	t.ok(not page.ink_tool.perform(), "so it refuses")
	page.player.position = f1.global_position + Vector2(20, 10)
	t.ok(page.sketch_blocked(f1), "a faint sketch never turns solid around Nib")
	await _free(t, page)


func test_save_round_trip(t) -> void:
	var state := {"sketches": {"f1": "inked", "f2": true}, "collected": ["drop"]}
	var page: ComicPage = await _build(t, state, ["ink"])
	t.ok(page.sketches["f1"].inked, "inked restored")
	t.eq(page.ink(), 0, "with the ink it implies")
	t.ok(not page.ink_drops.has("drop"), "a collected drop isn't drawn again")
	var st := page.capture_state()
	t.eq(st["sketches"]["f1"], "inked", "captured as inked")
	t.eq(st["collected"], ["drop"], "and the collected drop")
	await _free(t, page)

	# Ink spent that was never collected: the sketches start over.
	page = await _build(t, {"sketches": {"f1": "inked"}}, ["ink"])
	t.ok(not page.sketches["f1"].inked, "impossible save reset")
	t.eq(page.ink(), 0, "to an empty hat")
	await _free(t, page)
