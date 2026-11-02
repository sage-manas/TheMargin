extends Node
## The player's progress as one save document (SAVE_SCHEMA.md). Gameplay
## changes mark state dirty; this coalesces them into a single write per frame,
## then mirrors the save to the web host for cloud sync.

## Returns the live page snapshot: {page_id, page_state, player_position, carrying}.
## Set by the running page so saves capture the world without GameState
## knowing how pages are built.
var snapshot_provider: Callable

var save: Dictionary = {}
var playing := false
var _dirty := false
var _playtime := 0.0


func _ready() -> void:
	save = SaveManager.empty_save()
	EventBus.state_dirty.connect(request_commit)


func _process(delta: float) -> void:
	if playing and not get_tree().paused:
		_playtime += delta
		if _playtime >= 1.0:
			save["playtimeSec"] = int(save.get("playtimeSec", 0)) + int(_playtime)
			_playtime = fmod(_playtime, 1.0)


func new_game() -> void:
	save = SaveManager.empty_save()


func use_save(d: Dictionary) -> void:
	save = d


func current_page() -> String:
	return save["progress"]["page"]


func set_current_page(page_id: String) -> void:
	save["progress"]["page"] = page_id
	# Words belong to the page they were found on; a carried word stays behind.
	save["player"] = {"position": null, "carrying": null}


func complete_page(page_id: String) -> void:
	var done: Array = save["progress"]["completedPages"]
	if not done.has(page_id):
		done.append(page_id)


func page_state(page_id: String) -> Dictionary:
	return save["pages"].get(page_id, {})


func clear_page_state(page_id: String) -> void:
	save["pages"].erase(page_id)
	save["player"] = {"position": null, "carrying": null}


func request_commit() -> void:
	if _dirty:
		return
	_dirty = true
	_commit.call_deferred()


func commit_now() -> void:
	_dirty = true
	_commit()


func _commit() -> void:
	if not _dirty:
		return
	_dirty = false
	if snapshot_provider.is_valid():
		var snap: Dictionary = snapshot_provider.call()
		if not snap.is_empty():
			save["pages"][snap["page_id"]] = snap["page_state"]
			save["player"] = {"position": snap["player_position"], "carrying": snap["carrying"]}
	if SaveManager.write(save):
		WebBridge.send("SAVE_UPDATED", {"save": save})
