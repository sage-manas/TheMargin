extends RefCounted
## Every page in data/pages must be well formed: geometry on the grid,
## panels inside the page and a gutter apart, unique ids, known props and
## story actions, reachable `next`, pencil sketches inside their panels and
## within what the eraser can hold, platforms on rails that stay inside
## their panels, fallen bubbles inside their panels, nothing left stranded
## in a panel the artist erases, and scene cards, close-ups and conditional
## features that refer only to scenes and switches that exist.

const ACTIONS := ["wait", "rewrite_caption", "write_caption", "emote", "shake_panel", "sfx", "achievement", "end_card", "turn_page", "erase_panel"]
const EVENTS := ["page_entered", "link_formed", "word_taken", "word_placed", "door_opened", "panel_released", "panel_entered", "button_pressed", "button_released", "eraser_found", "sketch_erased", "sketch_restored", "ink_collected", "sketch_inked", "scene_changed", "switch_changed"]
## Object type -> word categories its label accepts.
const OBJECTS := {"door": ["state"], "crate": ["motion", "halt", "mass"], "button": ["mass"], "eraser": [], "ink": [], "platform": ["motion", "halt"], "lever": [], "dial": []}


func _pages() -> Array:
	var out := []
	for f in DirAccess.get_files_at(ComicPage.DATA_DIR):
		if f.ends_with(".json"):
			out.append(ComicPage.load_def(f.get_basename()))
	return out


func test_pages_parse(t) -> void:
	var pages := _pages()
	t.ok(pages.size() >= 2, "prototype has at least two pages")
	for d: Dictionary in pages:
		t.ok(d.has("id") and d.has("panels") and d.has("spawn"), "required keys in %s" % d.get("id"))


func test_geometry(t) -> void:
	var page := Rect2i(Vector2i.ZERO, PageConst.PAGE_SIZE)
	for d: Dictionary in _pages():
		var rects := []
		for pd: Dictionary in d.panels:
			var r := Rect2i(int(pd.rect[0]), int(pd.rect[1]), int(pd.rect[2]), int(pd.rect[3]))
			t.ok(page.encloses(r), "%s/%s inside the page" % [d.id, pd.id])
			t.ok(r.position.x % PageConst.GRID == 0 and r.position.y % PageConst.GRID == 0, "%s/%s on the grid" % [d.id, pd.id])
			if pd.has("track"):
				t.ok(int(pd.track.min) <= int(pd.rect[1 if pd.track.axis == "y" else 0]) and int(pd.rect[1 if pd.track.axis == "y" else 0]) <= int(pd.track.max), "%s/%s starts on its track" % [d.id, pd.id])
			rects.append(r)
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				t.ok(not (rects[i] as Rect2i).grow(PageConst.GUTTER).intersects(rects[j]), "%s: panels %d and %d a gutter apart" % [d.id, i, j])


func test_ids_and_references(t) -> void:
	for d: Dictionary in _pages():
		var ids := {}
		var captions := {}
		var npcs := {}
		var buttons := {}
		var wired := []
		var sketch_ids := {}
		var holds := int(d.get("eraser_holds", PlayerEraser.HOLDS))
		var hat := int(d.get("ink_holds", PlayerInk.HOLDS))
		for pd: Dictionary in d.panels:
			t.ok(not ids.has(pd.id), "unique panel id %s" % pd.id)
			ids[pd.id] = true
			var inner := Rect2i(Vector2i.ONE * PageConst.BORDER, Vector2i(int(pd.rect[2]), int(pd.rect[3])) - Vector2i.ONE * PageConst.BORDER * 2)
			for sk: Dictionary in pd.get("sketches", []):
				t.ok(not sketch_ids.has(sk.id), "%s: unique sketch id %s" % [d.id, sk.id])
				sketch_ids[sk.id] = true
				var r := Rect2i(int(sk.rect[0]), int(sk.rect[1]), int(sk.rect[2]), int(sk.rect[3]))
				t.ok(inner.encloses(r) and r.size.x > 0 and r.size.y > 0, "%s inside its panel" % sk.id)
				# A sketch that costs more than the eraser holds could never be drawn back.
				t.ok(int(sk.get("crumbs", 1)) >= 1 and int(sk.get("crumbs", 1)) <= holds, "%s: 1..%d crumbs" % [sk.id, holds])
				# Likewise ink: a cost the hat can't hold could never be traced.
				t.ok(int(sk.get("ink", 0)) >= 0 and int(sk.get("ink", 0)) <= hat, "%s: 0..%d ink" % [sk.id, hat])
				t.ok(not (sk.get("faint", false) and int(sk.get("ink", 0)) == 0), "%s: a faint sketch must be traceable" % sk.id)
			for c: Dictionary in pd.get("captions", []):
				# Captions that hold words are fixed text; story actions can't rewrite them.
				captions[c.id] = not Lettering.has_slots(c.get("text", ""))
				for m in RegEx.create_from_string(Lettering.SLOT_RE).search_all(c.get("text", "")):
					t.ok(m.get_string(1) == "" or WordLibrary.exists(m.get_string(1)), "caption word exists: %s" % m.get_string(1))
			for n: Dictionary in pd.get("npcs", []):
				npcs[n.id] = true
			for b: Dictionary in pd.get("bubbles", []):
				t.ok(not npcs.has(b.id) and not captions.has(b.id), "%s: bubble id %s is its own" % [d.id, b.id])
				for m in RegEx.create_from_string(Lettering.SLOT_RE).search_all(b.get("text", "")):
					t.ok(m.get_string(1) == "" or WordLibrary.exists(m.get_string(1)), "bubble word exists: %s" % m.get_string(1))
				var lt := Lettering.new()
				lt.parse(b.text, b.id, null, null, Vector2.ZERO)
				var bs := Vector2i(lt.max_width() + SpeechBubble.PAD.x * 2, lt.lines.size() * ComicFont.LINE_HEIGHT + SpeechBubble.PAD.y * 2 - 2)
				t.ok(inner.encloses(Rect2i(Vector2i(int(b.at[0]), int(b.at[1]) - bs.y), bs)), "%s: fallen bubble inside its panel" % b.id)
			if pd.get("erased", false):
				t.ok(not pd.has("track"), "%s/%s: an erased panel lies flat" % [d.id, pd.id])
				t.ok(_contents(pd).is_empty(), "%s/%s: an erased panel holds nothing (%s)" % [d.id, pd.id, _contents(pd)])
			for o: Dictionary in pd.get("objects", []):
				t.ok(OBJECTS.has(o.type), "known object type %s" % o.type)
				if o.has("label") and o.label != "":
					t.ok(WordLibrary.exists(o.label), "label word exists: %s" % o.label)
					t.ok(WordLibrary.category(o.label) in OBJECTS.get(o.type, []), "%s accepts its label %s" % [o.id, o.label])
				if o.type == "crate":
					t.ok(inner.encloses(Rect2i(Vector2i(int(o.at[0]), int(o.at[1])), Vector2i(Crate.SIZE))), "%s inside its panel" % o.id)
				if o.type == "platform":
					var rail: Dictionary = o.get("rail", {})
					var axis := 0 if rail.get("axis") == "x" else 1
					t.ok(rail.get("axis") in ["x", "y"] and int(rail.get("min", 0)) < int(rail.get("max", 0)), "%s: rail runs along x or y" % o.id)
					t.ok(int(o.at[axis]) >= int(rail.get("min", 0)) and int(o.at[axis]) <= int(rail.get("max", 0)), "%s starts on its rail" % o.id)
					var size := Vector2i(int(o.get("w", 32)), Platform.HEIGHT)
					var lo := Vector2i(int(o.at[0]), int(o.at[1]))
					var hi := lo
					lo[axis] = int(rail.get("min", 0))
					hi[axis] = int(rail.get("max", 0))
					t.ok(inner.encloses(Rect2i(lo, size)) and inner.encloses(Rect2i(hi, size)), "%s: whole rail inside its panel" % o.id)
					if o.has("label") and WordLibrary.category(o.label) == "motion":
						t.ok(Platform.heading_for(o.label, axis) != 0, "%s: label %s runs along its rail" % [o.id, o.label])
				if o.type in ["lever", "dial"]:
					buttons[o.id] = true
				if o.type == "button":
					buttons[o.id] = true
					t.ok(float(o.get("needs", 1.0)) > 0.0, "%s needs some weight" % o.id)
					t.ok(int(o.at[0]) >= PageConst.BORDER and int(o.at[0]) + int(PlateButton.SIZE.x) <= int(pd.rect[2]) - PageConst.BORDER, "%s inside its panel" % o.id)
				if o.type == "ink":
					t.ok(int(o.get("drops", 1)) >= 1 and int(o.get("drops", 1)) <= hat, "%s: 1..%d drops" % [o.id, hat])
				if o.type == "door" and o.has("button"):
					wired.append(o.button)
		for b: String in wired:
			t.ok(buttons.has(b), "%s: wired button exists: %s" % [d.id, b])
		for tr: Dictionary in d.get("triggers", []):
			t.ok(tr["on"] in EVENTS, "known event %s" % tr["on"])
			for a: Dictionary in tr["do"]:
				t.ok(a.action in ACTIONS, "known action %s" % a.action)
				if a.has("caption"):
					t.ok(captions.get(a.caption, false), "caption exists and is rewritable: %s" % a.caption)
				if a.has("npc"):
					t.ok(npcs.has(a.npc), "npc exists: %s" % a.npc)
				if a.has("panel"):
					t.ok(ids.has(a.panel), "panel exists: %s" % a.panel)
				if a.action == "erase_panel":
					_check_erasure(t, d, a)
		if d.get("next", "") != "":
			t.ok(not ComicPage.load_def(d.next).is_empty(), "next page exists: %s" % d.next)


## What a panel holds that the character could need or be standing on.
func _contents(pd: Dictionary) -> Array:
	var out := []
	for key: String in ["objects", "npcs", "bubbles", "sketches"]:
		if not pd.get(key, []).is_empty():
			out.append(key)
	for c: Dictionary in pd.get("captions", []):
		if Lettering.has_slots(c.get("text", "")):
			out.append("caption words")
	return out


## A panel the artist rubs out must leave nothing behind that the page needs,
## and the respawn point must be in a room that stays.
func _check_erasure(t, d: Dictionary, a: Dictionary) -> void:
	var target: Dictionary = {}
	for pd: Dictionary in d.panels:
		if pd.id == a.panel:
			target = pd
	t.ok(not target.has("track"), "%s: the erased panel %s is fixed" % [d.id, a.panel])
	t.ok(_contents(target).is_empty(), "%s: nothing stranded in %s (%s)" % [d.id, a.panel, _contents(target)])
	t.ok(a.has("respawn"), "%s: erasing %s moves the spawn" % [d.id, a.panel])
	if not a.has("respawn"):
		return
	var at := Vector2(a.respawn[0], a.respawn[1])
	var inside := false
	for pd: Dictionary in d.panels:
		var r := Rect2(pd.rect[0], pd.rect[1], pd.rect[2], pd.rect[3])
		if pd.id != a.panel and not pd.get("erased", false) and not pd.has("track") and r.encloses(Rect2(at - Vector2(Player.SIZE.x / 2.0, Player.SIZE.y), Player.SIZE)):
			inside = true
	t.ok(inside, "%s: respawn %s is in a fixed room that stays" % [d.id, at])


const FEATURES := ["vine", "ice", "gate", "glow_steps", "glow_text", "bridge"]


func test_scenes_and_closeups(t) -> void:
	for d: Dictionary in _pages():
		var switches := {}
		var panels := {}
		for pd: Dictionary in d.panels:
			panels[pd.id] = pd
			for o: Dictionary in pd.get("objects", []):
				if o.type in ["lever", "dial"]:
					switches[o.id] = true
					if o.type == "dial":
						t.ok(str(o.code).is_valid_int() and str(o.code).length() <= 8, "%s: a dial's code is digits" % o.id)
		var known := switches.duplicate()
		for sc in Conditions.SCENES:
			known[sc] = true
		var feature_ids := {}
		for pd: Dictionary in d.panels:
			var inner := Rect2i(Vector2i.ONE * PageConst.BORDER, Vector2i(int(pd.rect[2]), int(pd.rect[3])) - Vector2i.ONE * PageConst.BORDER * 2)
			for f: Dictionary in pd.get("features", []):
				t.ok(f.kind in FEATURES, "%s: known feature kind %s" % [d.id, f.kind])
				t.ok(not feature_ids.has(f.id), "%s: unique feature id %s" % [d.id, f.id])
				feature_ids[f.id] = true
				var r := Rect2i(int(f.rect[0]), int(f.rect[1]), int(f.rect[2]), int(f.rect[3]))
				t.ok(inner.encloses(r), "%s: feature %s inside its panel" % [d.id, f.id])
				for term in Conditions.terms(f.get("when", "")):
					t.ok(known.has(term), "%s: %s's condition names a scene or switch: %s" % [d.id, f.id, term])
			for n: Dictionary in pd.get("npcs", []):
				for term in Conditions.terms(n.get("when", "")):
					t.ok(known.has(term), "%s: %s's condition names a scene or switch: %s" % [d.id, n.id, term])
				if n.has("when") and n.has("bubble"):
					t.ok(not Lettering.has_slots(n.bubble.text), "%s: %s comes and goes, so their bubble holds no words" % [d.id, n.id])
			for pr: Dictionary in pd.get("props", []):
				for term in Conditions.terms(pr.get("when", "")):
					t.ok(known.has(term), "%s: a prop's condition names a scene or switch: %s" % [d.id, term])
		var held := {}
		for c: Dictionary in d.get("cards", []):
			t.ok(c.scene in Conditions.SCENES, "%s: card %s sets a known scene" % [d.id, c.id])
			t.ok(panels.has(c.panel), "%s: card %s starts on a panel" % [d.id, c.id])
			var pd: Dictionary = panels.get(c.panel, {})
			t.ok(not pd.get("pencil", false) and not pd.get("erased", false), "%s: card %s starts on an inked panel" % [d.id, c.id])
			t.ok(not held.has(c.panel), "%s: one card per panel (%s)" % [d.id, c.panel])
			held[c.panel] = true
		for cu: Dictionary in d.get("closeups", []):
			var c := Vector2(cu.at[0], cu.at[1])
			var r := float(cu.get("r", 28.0))
			var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
			t.ok(Rect2(Vector2.ZERO, Vector2(PageConst.PAGE_SIZE)).encloses(box), "%s: close-up %s on the page" % [d.id, cu.id])
			for pd: Dictionary in d.panels:
				if not pd.get("erased", false):
					var pr := Rect2(pd.rect[0], pd.rect[1], pd.rect[2], pd.rect[3])
					t.ok(not pr.intersects(box), "%s: close-up %s covers no panel (%s)" % [d.id, cu.id, pd.id])


func test_swaps_and_stretches(t) -> void:
	for d: Dictionary in _pages():
		var groups := {}
		for pd: Dictionary in d.panels:
			if pd.has("swap"):
				t.ok(not pd.has("track") and not pd.has("stretch"), "%s/%s: a swappable panel neither slides nor stretches" % [d.id, pd.id])
				if not groups.has(pd.swap):
					groups[pd.swap] = []
				groups[pd.swap].append(pd)
			if pd.has("stretch"):
				var lo := int(pd.stretch.min)
				var hi := int(pd.stretch.max)
				var w := int(pd.rect[2])
				t.ok(not pd.has("track"), "%s/%s: a stretchable panel doesn't slide" % [d.id, pd.id])
				t.ok(lo % PageConst.GRID == 0 and hi % PageConst.GRID == 0 and lo <= w and w <= hi, "%s/%s: starts within its stretch, on the grid" % [d.id, pd.id])
				var reach := Rect2i(int(pd.rect[0]), int(pd.rect[1]), hi, int(pd.rect[3]))
				t.ok(Rect2i(Vector2i.ZERO, PageConst.PAGE_SIZE).encloses(reach), "%s/%s: its widest reach is on the page" % [d.id, pd.id])
		for g: String in groups:
			var members: Array = groups[g]
			t.ok(members.size() >= 2, "%s: swap group %s has a partner" % [d.id, g])
			for pd: Dictionary in members:
				t.ok(int(pd.rect[2]) == int(members[0].rect[2]) and int(pd.rect[3]) == int(members[0].rect[3]), "%s: swap group %s is all one size" % [d.id, g])

