class_name StoryRunner
extends Node
## Data-driven narrative triggers (TDD §3.7):
##   {id, on, when?, once?, persist?, do: [actions]}
## `on` is an EventBus event; `when` matches its arguments. Fired `once`
## triggers are saved (unless persist=false) and their lasting effects are
## re-applied instantly on load instead of replaying.

const EVENTS := ["page_entered", "link_formed", "word_taken", "word_placed", "door_opened", "panel_released", "button_pressed", "button_released", "eraser_found", "sketch_erased", "sketch_restored", "ink_collected", "sketch_inked"]

var page: ComicPage
var triggers: Array = []
var fired := {}


func setup(owner_page: ComicPage, trigger_defs: Array, fired_ids: Array) -> void:
	page = owner_page
	triggers = trigger_defs
	for id: Variant in fired_ids:
		fired[str(id)] = true
	for t: Dictionary in triggers:
		if fired.has(t["id"]):
			for a: Dictionary in t["do"]:
				_apply_instant(a)
	EventBus.page_entered.connect(func(id: String) -> void: _on("page_entered", {"page": id}))
	EventBus.link_formed.connect(func(a: String, b: String) -> void: _on("link_formed", {"a": a, "b": b}))
	EventBus.word_taken.connect(func(s: String, w: String) -> void: _on("word_taken", {"slot": s, "word": w}))
	EventBus.word_placed.connect(func(s: String, w: String) -> void: _on("word_placed", {"slot": s, "word": w}))
	EventBus.door_opened.connect(func(d: String) -> void: _on("door_opened", {"object": d}))
	EventBus.button_pressed.connect(func(b: String) -> void: _on("button_pressed", {"object": b}))
	EventBus.button_released.connect(func(b: String) -> void: _on("button_released", {"object": b}))
	EventBus.panel_released.connect(func(p: String) -> void: _on("panel_released", {"panel": p}))
	EventBus.eraser_found.connect(func() -> void: _on("eraser_found", {}))
	EventBus.sketch_erased.connect(func(s: String) -> void: _on("sketch_erased", {"sketch": s}))
	EventBus.sketch_restored.connect(func(s: String) -> void: _on("sketch_restored", {"sketch": s}))
	EventBus.ink_collected.connect(func(o: String) -> void: _on("ink_collected", {"object": o}))
	EventBus.sketch_inked.connect(func(s: String) -> void: _on("sketch_inked", {"sketch": s}))


## Fired trigger ids that belong in the save.
func persisted_fired() -> Array:
	var out := []
	for t: Dictionary in triggers:
		if fired.has(t["id"]) and t.get("persist", true):
			out.append(t["id"])
	return out


static func matches(when: Dictionary, args: Dictionary) -> bool:
	for k: String in when:
		if str(args.get(k, "")) != str(when[k]):
			return false
	return true


func _on(event: String, args: Dictionary) -> void:
	for t: Dictionary in triggers:
		if t["on"] != event or not matches(t.get("when", {}), args):
			continue
		if t.get("once", true):
			if fired.has(t["id"]):
				continue
			fired[t["id"]] = true
			EventBus.state_dirty.emit()
		_run(t["do"])


func _run(actions: Array) -> void:
	for a: Dictionary in actions:
		if not is_inside_tree():
			return
		match a["action"]:
			"wait":
				await get_tree().create_timer(float(a["sec"])).timeout
			"rewrite_caption":
				await page.captions[a["caption"]].rewrite(a["text"])
			"write_caption":
				await page.captions[a["caption"]].write(a["text"])
			"emote":
				page.npcs[a["npc"]].emote(a["text"])
			"shake_panel":
				page.panels[a["panel"]].shake()
				Audio.play("shake")
			"sfx":
				Audio.play(a["sound"])
			"achievement":
				EventBus.achievement_unlocked.emit(a["code"])
			"end_card":
				page.end_reached.emit()
			_:
				push_warning("Unknown story action: %s" % a["action"])


## The lasting part of an action, applied without animation on load.
func _apply_instant(a: Dictionary) -> void:
	match a["action"]:
		"rewrite_caption", "write_caption":
			page.captions[a["caption"]].set_text_instant(a["text"])
