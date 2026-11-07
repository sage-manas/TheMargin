extends Node
## Game flow: title → page → page turn → … → end card (STATE_DIAGRAMS.md).
## Owns the current ComicPage and the UI layer; everything global lives in
## the autoloads.

const RESET_HOLD := 0.7

var world: Node2D
var ui: CanvasLayer
var title: TitleScreen
var pause_menu: Overlay
var end_card: Overlay
var turn: PageTurn
var hud: Hud
var page: ComicPage

var _busy := false
var _reset_hold := 0.0


func _ready() -> void:
	WordLibrary.load_words()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ui = CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	turn = PageTurn.new()
	ui.add_child(turn)
	title = TitleScreen.new()
	ui.add_child(title)
	title.chosen.connect(_on_title)
	pause_menu = Overlay.new()
	pause_menu.title = "PAUSED"
	ui.add_child(pause_menu)
	pause_menu.chosen.connect(_on_pause_choice)
	end_card = Overlay.new()
	end_card.title = "END OF CHAPTER 1"
	end_card.subtitle = "CHAPTER 2 IS STILL BEING DRAWN.|THANK YOU FOR PLAYING THE MARGIN."
	end_card.dim = 0.2
	ui.add_child(end_card)
	end_card.chosen.connect(_on_end_choice)

	WebBridge.cloud_save_received.connect(_on_cloud_save)
	WebBridge.pause_requested.connect(func() -> void: _set_paused(true))
	WebBridge.resume_requested.connect(func() -> void: _set_paused(false))
	EventBus.achievement_unlocked.connect(func(code: String) -> void: WebBridge.send("ACHIEVEMENT_UNLOCKED", {"code": code}))

	var sandbox := _sandbox_arg()
	if sandbox != "":
		_play_sandbox(sandbox)
		return
	_show_title()
	WebBridge.send("GAME_READY", {
		"version": str(ProjectSettings.get_setting("application/config/version")),
		"hasSave": SaveManager.has_save(),
	})


## `godot --path apps/game -- --page=sb_mechanics` opens a sandbox page
## directly. Sandbox pages never touch the save.
func _sandbox_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			return a.trim_prefix("--page=")
	return ""


func _play_sandbox(id: String) -> void:
	title.visible = false
	title.menu.active = false
	GameState.sandbox = true
	GameState.new_game()
	GameState.playing = true
	Audio.start_ambience()
	await _load_page(id, false)


func _show_title() -> void:
	var s := SaveManager.load_save()
	title.refresh(not s.is_empty())
	# Warm up the music for where play will resume while the title is up.
	var resume: String = (s if not s.is_empty() else SaveManager.empty_save())["progress"]["page"]
	Audio.prepare_music(Audio.track_for_page(ComicPage.load_def(resume)))
	title.visible = true
	title.menu.active = true


func _on_title(action: String) -> void:
	match action:
		"continue":
			var s := SaveManager.load_save()
			if s.is_empty():
				GameState.new_game()
			else:
				GameState.use_save(s)
		"new":
			GameState.new_game()
		_:
			return
	title.visible = false
	title.menu.active = false
	Audio.start_ambience()
	GameState.playing = true
	await _load_page(GameState.current_page(), false)
	WebBridge.send("GAME_STARTED", {"pageId": GameState.current_page()})


## Replaces the current page. With `animate`, the old page turns over the
## new one; with `fade`, it cross-fades (resets and reduced motion).
func _load_page(id: String, animate: bool, fade := false) -> void:
	_busy = true
	var snapshot: Texture2D = null
	if page and (animate or fade):
		snapshot = await turn.capture()
	if page:
		page.drag.release_all()
		world.remove_child(page)
		page.queue_free()
		page = null
	if id != GameState.current_page():
		GameState.set_current_page(id)
	var def := ComicPage.load_def(id)
	page = ComicPage.new()
	world.add_child(page)
	page.build(def, GameState.page_state(id), GameState.save["player"], GameState.save["progress"]["abilities"])
	Audio.play_music(Audio.track_for_page(def))
	page.exit_requested.connect(_on_page_exit)
	page.end_reached.connect(_on_end_reached)
	GameState.snapshot_provider = page.snapshot
	if snapshot:
		await turn.play(snapshot, fade or Settings.reduced_motion)
	_busy = false
	EventBus.page_entered.emit(id)
	GameState.request_commit()


func _on_page_exit() -> void:
	var done := page.page_id
	var next: String = page.def.get("next", "")
	GameState.complete_page(done)
	EventBus.page_completed.emit(done)
	WebBridge.send("PAGE_COMPLETED", {"pageId": done})
	if next == "":
		_on_end_reached()
		return
	await _load_page(next, true)


func _on_end_reached() -> void:
	GameState.commit_now()
	Audio.play("chime")
	page.player.input_locked = true
	end_card.open([{"label": "BACK TO TITLE", "action": "title"}])


func _on_end_choice(action: String) -> void:
	if action == "title":
		end_card.close()
		_quit_to_title()


func _quit_to_title() -> void:
	GameState.commit_now()
	GameState.playing = false
	GameState.snapshot_provider = Callable()
	Audio.stop_music()
	if page:
		world.remove_child(page)
		page.queue_free()
		page = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_show_title()


func reset_page() -> void:
	if page == null or _busy:
		return
	Audio.play("shake")
	GameState.clear_page_state(page.page_id)
	await _load_page(page.page_id, false, true)


# --- pause -------------------------------------------------------------------

func _set_paused(paused: bool) -> void:
	if page == null or _busy or end_card.visible:
		return
	if paused == get_tree().paused:
		return
	get_tree().paused = paused
	if paused:
		page.drag.release_all()
		GameState.commit_now()
		pause_menu.open([{"label": "RESUME", "action": "resume"}, {"label": "RESET PAGE", "action": "reset"}] + Screens.settings_items() + [{"label": "QUIT TO TITLE", "action": "title"}])
		WebBridge.send("GAME_PAUSED")
	else:
		pause_menu.close()
		WebBridge.send("GAME_RESUMED")


func _on_pause_choice(action: String) -> void:
	if Screens.handle_setting(action):
		return
	match action:
		"resume":
			_set_paused(false)
		"reset":
			_set_paused(false)
			reset_page()
		"title":
			_set_paused(false)
			_quit_to_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and page and not end_card.visible:
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Browser tab hidden / window blurred: pause and make sure progress is on disk.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if page and not get_tree().paused:
			_set_paused(true)


func _process(delta: float) -> void:
	var holding := page != null and not _busy and not get_tree().paused and not end_card.visible and Input.is_action_pressed("reset_page")
	_reset_hold = _reset_hold + delta if holding else 0.0
	hud.reset_progress = clampf(_reset_hold / RESET_HOLD, 0.0, 1.0) if holding else 0.0
	hud.panel_mode = page != null and page.drag.panel_mode_active()
	hud.queue_redraw()
	if _reset_hold >= RESET_HOLD:
		_reset_hold = 0.0
		reset_page()


func _on_cloud_save(save: Dictionary) -> void:
	# The host only sends this when the cloud copy wins conflict resolution.
	SaveManager.write(save)
	GameState.use_save(save)
	if page:
		await _load_page(GameState.current_page(), false, true)
	else:
		_show_title()
