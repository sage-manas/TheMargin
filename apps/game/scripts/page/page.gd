class_name ComicPage
extends Node2D
## A comic page built from data/pages/<id>.json (ADR-0003). Owns the panels,
## the link graph, the word slots, the character and the reader's hand.

signal exit_requested
signal end_reached

const DATA_DIR := "res://data/pages/"
const PAPER := preload("res://shaders/paper.gdshader")

var page_id := ""
var def: Dictionary = {}
var panels: Dictionary = {}
var panel_list: Array[ComicPanel] = []
var slots: Dictionary = {}
var captions: Dictionary = {}
var npcs: Dictionary = {}
var doors: Array[Door] = []
var crates: Dictionary = {}
var platforms: Dictionary = {}
var buttons: Dictionary = {}
var sketches: Dictionary = {}
## Abilities Nib has found so far (`progress.abilities`), e.g. "eraser".
var abilities: Array = []
## Crumbs the eraser can hold on this page (`eraser_holds`).
var eraser_holds := PlayerEraser.HOLDS
## Drops of ink Nib's hat holds on this page (`ink_holds`).
var ink_holds := PlayerInk.HOLDS
var ink_drops: Dictionary = {}
## Ids of ink pickups already collected, and the drops each held.
var collected: Dictionary = {}
var links: Array = []
var player: Player
var interaction: PlayerInteraction
var eraser: PlayerEraser
var ink_tool: PlayerInk
## Nib's sketch tools, bottom prompt first.
var tools: Array[SketchTool] = []
var drag: PanelDrag
var story: StoryRunner
var spawn := Vector2.ZERO

var _bridges: DrawLayer
var _exited := false


static func load_def(id: String) -> Dictionary:
	var path := DATA_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("Missing page data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## `state` is this page's saved state; `player_state` is {position, carrying};
## `found` is `progress.abilities`.
func build(page_def: Dictionary, state: Dictionary = {}, player_state: Dictionary = {}, found: Array = []) -> void:
	def = page_def
	page_id = def["id"]
	abilities = found.duplicate()
	eraser_holds = int(def.get("eraser_holds", PlayerEraser.HOLDS))
	ink_holds = int(def.get("ink_holds", PlayerInk.HOLDS))
	for id: Variant in state.get("collected", []):
		collected[str(id)] = 0
	var bg := ColorRect.new()
	bg.size = Vector2(PageConst.PAGE_SIZE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -10
	var mat := ShaderMaterial.new()
	mat.shader = PAPER
	mat.set_shader_parameter("paper", Palette.PAGE)
	mat.set_shader_parameter("fiber", Palette.PAGE_FIBER)
	bg.material = mat
	add_child(bg)
	add_child(DrawLayer.make(_draw_margin, -9))

	for pd: Dictionary in def["panels"]:
		_build_panel(pd)
	_apply_state(state)
	_bridges = DrawLayer.make(_draw_bridges, 1)
	add_child(_bridges)
	relink(true)

	var sp: Array = def["spawn"]
	spawn = Vector2(sp[0], sp[1])
	player = Player.new()
	player.page = self
	player.position = _restore_position(player_state.get("position"))
	add_child(player)
	_wire_buttons()

	var carried: Variant = player_state.get("carrying")
	interaction = PlayerInteraction.new()
	interaction.setup(self, player, carried if carried is String and WordLibrary.exists(carried) else "")
	add_child(interaction)
	eraser = PlayerEraser.new()
	eraser.setup(self, player, 0)
	ink_tool = PlayerInk.new()
	ink_tool.setup(self, player, 1)
	tools = [eraser, ink_tool]
	for t in tools:
		add_child(t)
	drag = PanelDrag.new()
	drag.page = self
	add_child(drag)
	story = StoryRunner.new()
	add_child(story)
	story.setup(self, def.get("triggers", []), state.get("fired", []))


func _build_panel(pd: Dictionary) -> void:
	var p := ComicPanel.new()
	p.setup(pd)
	add_child(p)
	panels[p.panel_id] = p
	panel_list.append(p)
	for c: Dictionary in pd.get("captions", []):
		var cap := Caption.new()
		cap.setup(c)
		p.content.add_child(cap)
		captions[cap.caption_id] = cap
		for s in cap.slots:
			_register_slot(s, p)
			p.caption_slots.append(s)
	for sd: Dictionary in pd.get("sketches", []):
		var sk := Sketch.new()
		sk.setup(sd)
		sk.panel = p
		p.content.add_child(sk)
		sketches[sk.sketch_id] = sk
	for n: Dictionary in pd.get("npcs", []):
		var npc := Npc.new()
		npc.setup(n)
		p.content.add_child(npc)
		npcs[npc.npc_id] = npc
		if n.has("bubble"):
			var bubble := SpeechBubble.new()
			bubble.setup(n["bubble"], npc)
			p.content.add_child(bubble)
			for s in bubble.slots:
				_register_slot(s, p)
	for o: Dictionary in pd.get("objects", []):
		match o["type"]:
			"door":
				var d := Door.new()
				d.setup(o)
				p.content.add_child(d)
				doors.append(d)
				_register_slot(d.slot, p)
			"crate":
				var c := Crate.new()
				c.setup(o)
				c.page = self
				c.panel = p
				p.content.add_child(c)
				crates[c.crate_id] = c
				_register_slot(c.slot, p)
			"platform":
				var pl := Platform.new()
				pl.setup(o)
				pl.page = self
				pl.panel = p
				p.content.add_child(pl)
				platforms[pl.platform_id] = pl
				_register_slot(pl.slot, p)
			"button":
				var b := PlateButton.new()
				b.setup(o)
				b.page = self
				p.content.add_child(b)
				buttons[b.button_id] = b
				_register_slot(b.slot, p)
			"eraser":
				if not has_eraser():
					var e := EraserPickup.new()
					e.setup(o)
					e.page = self
					p.content.add_child(e)
			"ink":
				var drop := InkDrop.new()
				drop.setup(o)
				if collected.has(drop.drop_id):
					collected[drop.drop_id] = drop.drops
					drop.free()
					continue
				drop.page = self
				p.content.add_child(drop)
				ink_drops[drop.drop_id] = drop
			_:
				push_warning("Unknown object type: %s" % o["type"])


## Settles every button against where things already rest, without sound,
## then lets wired doors follow their buttons from here on.
func _wire_buttons() -> void:
	for b: PlateButton in buttons.values():
		b.refresh(false)
	for d in doors:
		var b: PlateButton = buttons.get(d.button_id)
		if b == null:
			continue
		d.set_powered(b.pressed, false)
		b.changed.connect(d.set_powered)


func _register_slot(s: WordSlot, p: ComicPanel) -> void:
	s.panel = p
	slots[s.id] = s


func _apply_state(state: Dictionary) -> void:
	# Saved pickups this page doesn't have hold no ink.
	for id: String in collected.keys():
		if collected[id] == 0:
			collected.erase(id)
	var saved_panels: Dictionary = state.get("panels", {})
	for id: String in saved_panels:
		var p: ComicPanel = panels.get(id)
		var pos: Variant = saved_panels[id]
		if p and p.is_lifted() and pos is Array and pos.size() == 2:
			var target := Vector2i(int(pos[0]), int(pos[1]))
			if _on_track(p, target) and _panel_fits(p, target):
				p.position = Vector2(target)
	var saved_slots: Dictionary = state.get("slots", {})
	for id: String in saved_slots:
		var s: WordSlot = slots.get(id)
		var w: Variant = saved_slots[id]
		if s == null:
			continue
		if w == null:
			s.word = ""
		elif w is String and WordLibrary.exists(w) and s.accepts_word(w):
			s.word = w
			s.loose = true
		s.holder.refresh(false)
	var saved_objects: Dictionary = state.get("objects", {})
	for id: String in saved_objects:
		var pos: Variant = saved_objects[id]
		var pl: Platform = platforms.get(id)
		if pl and pos is Array and pos.size() == 2 and pl.on_rail(Vector2i(int(pos[0]), int(pos[1]))):
			pl.position = Vector2(int(pos[0]), int(pos[1]))
		var c: Crate = crates.get(id)
		if c and pos is Array and pos.size() == 2:
			var at := Vector2(int(pos[0]), int(pos[1]))
			var inner := Rect2(Vector2.ONE * PageConst.BORDER, Vector2(c.panel.size) - Vector2.ONE * PageConst.BORDER * 2)
			if inner.encloses(Rect2(at, Crate.SIZE)):
				c.position = at
	var saved_sketches: Dictionary = state.get("sketches", {})
	for id: String in saved_sketches:
		var sk: Sketch = sketches.get(id)
		if sk:
			sk.apply_state(saved_sketches[id])
	# Crumbs and ink are derived, so a save can't hold more than the eraser or
	# the hat does, or owe what it never had. If one does, the sketches start
	# over (collected ink stays collected).
	var crumbs_now := crumbs()
	var ink_now := ink()
	if crumbs_now < 0 or crumbs_now > eraser_holds or ink_now < 0 or ink_now > ink_holds:
		for sk: Sketch in sketches.values():
			sk.reset()
		if ink() > ink_holds:
			collected.clear()


func _restore_position(pos: Variant) -> Vector2:
	if pos is Array and pos.size() == 2:
		var v := Vector2(float(pos[0]), float(pos[1]))
		var r := Rect2(v + Vector2(-Player.SIZE.x / 2.0, -Player.SIZE.y), Player.SIZE)
		for p in panel_list:
			if p.encloses(r):
				return v
	return spawn


# --- panels and links ------------------------------------------------------

func relink(silent := false) -> void:
	var infos := []
	for p in panel_list:
		infos.append(p.info())
	var new_links := PanelLinks.compute(infos)
	for p in panel_list:
		p.set_gaps(PanelLinks.gaps_for(p.panel_id, p.rect(), new_links))
	if not silent:
		var old_keys := links.map(func(l: Dictionary) -> String: return PanelLinks.key(l))
		var new_keys := new_links.map(func(l: Dictionary) -> String: return PanelLinks.key(l))
		for l: Dictionary in new_links:
			if not old_keys.has(PanelLinks.key(l)):
				Audio.play("link")
				EventBus.link_formed.emit(l.a, l.b)
		for l: Dictionary in links:
			if not new_keys.has(PanelLinks.key(l)):
				Audio.play("unlink")
				EventBus.link_broken.emit(l.a, l.b)
	links = new_links
	if _bridges:
		_bridges.queue_redraw()


func _on_track(p: ComicPanel, pos: Vector2i) -> bool:
	var axis := 0 if p.track.get("axis") == "x" else 1
	var fixed := Vector2i(p.position)
	if pos[1 - axis] != fixed[1 - axis]:
		return false
	return pos[axis] >= int(p.track["min"]) and pos[axis] <= int(p.track["max"]) and pos[axis] % PageConst.GRID == 0


## A panel may not come closer than one gutter to any other panel.
func _panel_fits(p: ComicPanel, pos: Vector2i) -> bool:
	var r := Rect2i(pos, p.size).grow(PageConst.GUTTER)
	for other in panel_list:
		if other != p and r.intersects(other.rect()):
			return false
	return true


## Slides a lifted panel along its track toward `target`, one grid step at a
## time, carrying the character if they are inside. Stops at the first step
## that is blocked or would pull the floor out from under the character.
## Returns the number of steps moved.
func move_panel_toward(p: ComicPanel, target: Vector2i) -> int:
	if not p.is_lifted() or p.is_pinned():
		return 0
	var axis := 0 if p.track.get("axis") == "x" else 1
	var cur := Vector2i(p.position)
	var goal := clampi(snappedi(target[axis], PageConst.GRID), int(p.track["min"]), int(p.track["max"]))
	var moved := 0
	while cur[axis] != goal:
		if is_player_in_gutter():
			break
		var next := cur
		next[axis] += PageConst.GRID * signi(goal - cur[axis])
		if not _panel_fits(p, next):
			break
		var carries := p.encloses(player.collision_rect()) if player else false
		p.position = Vector2(next)
		if carries:
			player.position += Vector2(next - cur)
		cur = next
		moved += 1
		Audio.play("tick", 0.08, -4.0)
		relink()
		EventBus.panel_moved.emit(p.panel_id, cur)
	return moved


func player_panel() -> ComicPanel:
	var r := player.collision_rect()
	for p in panel_list:
		if p.encloses(r):
			return p
	return null


func is_player_in_gutter() -> bool:
	return player != null and player_panel() == null


# --- eraser ----------------------------------------------------------------

func has_eraser() -> bool:
	return abilities.has("eraser")


func find_eraser() -> void:
	if has_eraser():
		return
	abilities.append("eraser")
	Audio.play("take")
	EventBus.eraser_found.emit()
	EventBus.state_dirty.emit()


## Crumbs in hand: what rubbing sketches out has left, less what drawing
## smudges back has used (GDD §4.3). Derived, so it is never saved.
func crumbs() -> int:
	var total := 0
	for sk: Sketch in sketches.values():
		total += sk.crumb_balance()
	return total


# --- ink -------------------------------------------------------------------

func has_ink() -> bool:
	return abilities.has("ink")


## Collects a pickup if the hat has room for all of it. The first ink Nib
## collects is the ability to trace.
func collect_ink(drop: InkDrop) -> bool:
	if collected.has(drop.drop_id) or ink() + drop.drops > ink_holds:
		return false
	collected[drop.drop_id] = drop.drops
	ink_drops.erase(drop.drop_id)
	if not has_ink():
		abilities.append("ink")
	Audio.play("drip")
	EventBus.ink_collected.emit(drop.drop_id)
	EventBus.state_dirty.emit()
	return true


## Ink in the hat: drops collected on this page less what tracing has spent
## (GDD §4.4). Derived, so it is never saved.
func ink() -> int:
	var total := 0
	for n: int in collected.values():
		total += n
	for sk: Sketch in sketches.values():
		total -= sk.ink_spent()
	return total


## Drawing a sketch back over Nib, a crate or a platform would trap them
## inside it.
func sketch_blocked(sk: Sketch) -> bool:
	var r := sk.rect().grow(-0.01)
	if player and r.intersects(player.collision_rect()):
		return true
	for c: Crate in crates.values():
		if r.intersects(c.rect()):
			return true
	for pl: Platform in platforms.values():
		if r.intersects(pl.rect()):
			return true
	return false


# --- runtime ---------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if player == null or _exited:
		return
	# Safety net: nothing should let Nib leave the page, but never soft-lock.
	if not Rect2(Vector2.ZERO, Vector2(PageConst.PAGE_SIZE)).has_point(player.position):
		player.position = spawn
		player.velocity = Vector2.ZERO
	for d in doors:
		if d.exit and d.is_open and d.doorway_rect().has_point(player.global_position + Vector2(0, -4)):
			turn()
			return


## Leaves the page for `next`, once: through an exit door, or when the story
## turns the page itself (`turn_page`).
func turn() -> void:
	if _exited:
		return
	_exited = true
	player.input_locked = true
	player.velocity = Vector2.ZERO
	exit_requested.emit()


## The page's save state (SAVE_SCHEMA §2, pages.<id>).
func capture_state() -> Dictionary:
	var st := {"panels": {}, "slots": {}, "objects": {}, "sketches": {}, "collected": collected.keys(), "fired": story.persisted_fired()}
	for p in panel_list:
		if p.is_lifted():
			st["panels"][p.panel_id] = [int(p.position.x), int(p.position.y)]
	for id: String in slots:
		var w: String = slots[id].word
		st["slots"][id] = w if w != "" else null
	for id: String in crates:
		var c: Crate = crates[id]
		st["objects"][id] = [int(c.position.x), int(c.position.y)]
	for id: String in platforms:
		var pl: Platform = platforms[id]
		st["objects"][id] = [int(pl.position.x), int(pl.position.y)]
	for id: String in sketches:
		st["sketches"][id] = sketches[id].state()
	return st


func snapshot() -> Dictionary:
	var pos: Variant = null
	if not is_player_in_gutter() and player.is_on_floor():
		pos = [int(roundf(player.position.x)), int(roundf(player.position.y))]
	return {
		"page_id": page_id,
		"page_state": capture_state(),
		"player_position": pos,
		"carrying": interaction.carrying if interaction.carrying != "" else null,
		"abilities": abilities.duplicate(),
	}


# --- drawing ---------------------------------------------------------------

func _draw_bridges(ci: CanvasItem) -> void:
	var g := PageConst.GUTTER
	for l: Dictionary in links:
		var a: ComicPanel = panels[l.a]
		if l.axis == "h":
			var x := float(a.rect().end.x)
			ci.draw_rect(Rect2(x - 2, l.from, g + 4, l.to - l.from), Palette.PAPER)
			ci.draw_rect(Rect2(x - 2, l.from - 2, g + 4, 2), Palette.INK)
			ci.draw_rect(Rect2(x - 2, l.to, g + 4, 2), Palette.INK)
		else:
			var y := float(a.rect().end.y)
			ci.draw_rect(Rect2(l.from, y - 2, l.to - l.from, g + 4), Palette.PAPER)
			ci.draw_rect(Rect2(l.from - 2, y - 2, 2, g + 4), Palette.INK)
			ci.draw_rect(Rect2(l.to, y - 2, 2, g + 4), Palette.INK)


func _draw_margin(ci: CanvasItem) -> void:
	if def.has("hint"):
		PixelFont.draw_centered(ci, PageConst.PAGE_SIZE.x / 2.0, PageConst.PAGE_SIZE.y - 12, def["hint"], Palette.PENCIL)
	if def.has("number"):
		var number := str(int(def["number"]))
		PixelFont.draw(ci, Vector2(PageConst.PAGE_SIZE.x - 10 - PixelFont.measure(number), PageConst.PAGE_SIZE.y - 12), number, Palette.PENCIL)
	for n: Dictionary in def.get("notes", []):
		var at: Array = n["at"]
		PixelFont.draw_lines(ci, Vector2(at[0], at[1]), n["text"], Palette.PENCIL)
