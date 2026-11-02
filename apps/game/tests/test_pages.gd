extends RefCounted
## Every page in data/pages must be well formed: geometry on the grid,
## panels inside the page and a gutter apart, unique ids, known props and
## story actions, reachable `next`.

const ACTIONS := ["wait", "rewrite_caption", "write_caption", "emote", "shake_panel", "sfx", "achievement", "end_card"]
const EVENTS := ["page_entered", "link_formed", "word_taken", "word_placed", "door_opened", "panel_released"]


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
		for pd: Dictionary in d.panels:
			t.ok(not ids.has(pd.id), "unique panel id %s" % pd.id)
			ids[pd.id] = true
			for c: Dictionary in pd.get("captions", []):
				captions[c.id] = true
			for n: Dictionary in pd.get("npcs", []):
				npcs[n.id] = true
			for o: Dictionary in pd.get("objects", []):
				if o.has("label") and o.label != "":
					t.ok(WordLibrary.exists(o.label), "label word exists: %s" % o.label)
		for tr: Dictionary in d.get("triggers", []):
			t.ok(tr["on"] in EVENTS, "known event %s" % tr["on"])
			for a: Dictionary in tr["do"]:
				t.ok(a.action in ACTIONS, "known action %s" % a.action)
				if a.has("caption"):
					t.ok(captions.has(a.caption), "caption exists: %s" % a.caption)
				if a.has("npc"):
					t.ok(npcs.has(a.npc), "npc exists: %s" % a.npc)
				if a.has("panel"):
					t.ok(ids.has(a.panel), "panel exists: %s" % a.panel)
		if d.get("next", "") != "":
			t.ok(not ComicPage.load_def(d.next).is_empty(), "next page exists: %s" % d.next)
