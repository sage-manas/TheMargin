extends Node
## Versioned local save I/O (docs/architecture/SAVE_SCHEMA.md).
## user:// is backed by IndexedDB on the web; Godot syncs it when a file
## opened for writing is closed.

const PATH := "user://save_main.json"
const BACKUP_PATH := "user://save_main.bak.json"
const SCHEMA := "the-margin.save"
const CURRENT_VERSION := 1
const MAX_BYTES := 65536
const WEB_KEY := "the-margin.save_main"
const WEB_SOURCE := "localStorage"

## Ordered migrations: MIGRATIONS[n] upgrades a version-n save to n+1.
## Empty while only version 1 exists; each future entry needs a fixture test.
const MIGRATIONS := {}

## True when the save on disk was written by a newer build. We then play in
## memory and never overwrite it (SAVE_SCHEMA §4).
var read_only := false


static func empty_save() -> Dictionary:
	return {
		"schema": SCHEMA,
		"version": CURRENT_VERSION,
		"revision": 0,
		"updatedAt": "",
		"playtimeSec": 0,
		"progress": {
			"chapter": "ch01",
			"page": "ch01_p01",
			"completedPages": [],
			"completedChapters": [],
			"abilities": [],
			"flags": {},
		},
		"player": {"position": null, "carrying": null},
		"pages": {},
	}


func has_save() -> bool:
	return FileAccess.file_exists(PATH) or _web_get() != ""


## Loads, migrates and validates the save. Returns {} when there is no usable
## save. On the web, the localStorage mirror and the user:// file are both
## read and the higher revision wins; the backup is the last resort.
func load_save() -> Dictionary:
	read_only = false
	var best := {}
	for source in [PATH, WEB_SOURCE]:
		var s := _read_source(source)
		if read_only:
			return {}
		if not s.is_empty() and int(s.get("revision", 0)) > int(best.get("revision", -1)):
			best = s
	if best.is_empty():
		best = _read_source(BACKUP_PATH)
		if read_only:
			return {}
	return best


func _read_source(source: String) -> Dictionary:
	var text := ""
	if source == WEB_SOURCE:
		text = _web_get()
	elif FileAccess.file_exists(source):
		text = FileAccess.get_file_as_string(source)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		_discard(source)
		return {}
	var save: Dictionary = parsed
	if int(save.get("version", 0)) > CURRENT_VERSION:
		read_only = true
		push_warning("Save was written by a newer version; playing without saving.")
		return {}
	save = migrate(save, MIGRATIONS)
	var err := validate(save)
	if err != "":
		push_warning("Save rejected (%s): %s" % [source, err])
		_discard(source)
		return {}
	return save


func write(save: Dictionary) -> bool:
	if read_only:
		return false
	save["revision"] = int(save.get("revision", 0)) + 1
	save["updatedAt"] = Time.get_datetime_string_from_system(true) + "Z"
	var text := JSON.stringify(save)
	if text.length() > MAX_BYTES:
		push_error("Save exceeds %d bytes; not written." % MAX_BYTES)
		return false
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, BACKUP_PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save for writing: %s" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.close()
	_web_set(text)
	return true


func delete_save() -> void:
	for path in [PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var ls := _local_storage()
	if ls:
		ls.removeItem(WEB_KEY)
	read_only = false


func _discard(source: String) -> void:
	if source == WEB_SOURCE:
		var ls := _local_storage()
		if ls:
			ls.removeItem(WEB_KEY)
		return
	var dest := "%s.corrupt-%d.json" % [source.get_basename(), Time.get_unix_time_from_system()]
	DirAccess.rename_absolute(source, dest)


# --- web mirror ----------------------------------------------------------------
# On the web, user:// reaches IndexedDB through an asynchronous sync, and a
# reload inside that window was measured to restore the previous save (Risk R5).
# localStorage writes are synchronous, so every save is mirrored there too.

func _local_storage() -> JavaScriptObject:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.get_interface("localStorage")


func _web_get() -> String:
	var ls := _local_storage()
	if ls == null:
		return ""
	var v: Variant = ls.getItem(WEB_KEY)
	return v if v is String else ""


func _web_set(text: String) -> void:
	var ls := _local_storage()
	if ls:
		ls.setItem(WEB_KEY, text)


## Applies migrations in order until CURRENT_VERSION. `migrations` maps a
## version number to a Callable(Dictionary) -> Dictionary.
static func migrate(save: Dictionary, migrations: Dictionary, target := CURRENT_VERSION) -> Dictionary:
	var v := int(save.get("version", 1))
	while v < target:
		if not migrations.has(v):
			break
		save = (migrations[v] as Callable).call(save)
		v += 1
		save["version"] = v
	return save


static func _is_id_list(v: Variant, pattern: RegEx) -> bool:
	if not v is Array:
		return false
	for item: Variant in v:
		if not (item is String and pattern.search(item) != null):
			return false
	return true


## Returns "" if valid, otherwise a reason. Mirrors packages/contracts/src/save.ts.
static func validate(save: Dictionary) -> String:
	if save.get("schema") != SCHEMA:
		return "schema"
	if int(save.get("version", 0)) != CURRENT_VERSION:
		return "version"
	var progress: Variant = save.get("progress")
	if not progress is Dictionary:
		return "progress"
	var page_re := RegEx.create_from_string("^ch\\d\\d_p\\d\\d$")
	if not (progress.get("page") is String and page_re.search(progress["page"]) != null):
		return "progress.page"
	if not _is_id_list(progress.get("completedPages", []), page_re):
		return "progress.completedPages"
	var player: Variant = save.get("player")
	if not player is Dictionary:
		return "player"
	var carrying: Variant = player.get("carrying")
	if carrying != null:
		if not (carrying is String and RegEx.create_from_string("^[A-Z]{1,12}$").search(carrying) != null):
			return "player.carrying"
	var pos: Variant = player.get("position")
	if pos != null:
		if not (pos is Array and pos.size() == 2):
			return "player.position"
	if not save.get("pages") is Dictionary:
		return "pages"
	return ""
