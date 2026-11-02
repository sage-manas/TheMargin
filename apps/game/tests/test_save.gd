extends RefCounted
## Save format, validation, migration and disk round trip (SAVE_SCHEMA.md).


func test_empty_save_is_valid(t) -> void:
	t.eq(SaveManager.validate(SaveManager.empty_save()), "", "fresh save validates")


func test_validation_rejects_bad_fields(t) -> void:
	var s := SaveManager.empty_save()
	s["progress"]["page"] = "../../etc"
	t.eq(SaveManager.validate(s), "progress.page", "page id format")
	s = SaveManager.empty_save()
	s["player"]["carrying"] = "<script>"
	t.eq(SaveManager.validate(s), "player.carrying", "word id format")
	s = SaveManager.empty_save()
	s["schema"] = "other"
	t.eq(SaveManager.validate(s), "schema", "schema tag")


func test_migrations_apply_in_order(t) -> void:
	var migrations := {
		1: func(d: Dictionary) -> Dictionary:
			d["a"] = 1
			return d,
		2: func(d: Dictionary) -> Dictionary:
			d["b"] = d["a"] + 1
			return d,
	}
	var out := SaveManager.migrate({"version": 1}, migrations, 3)
	t.eq(out["version"], 3, "version bumped to target")
	t.eq(out["b"], 2, "migrations ran in order")


func test_round_trip_on_disk(t) -> void:
	SaveManager.delete_save()
	var s := SaveManager.empty_save()
	s["pages"]["ch01_p01"] = {"panels": {"p3": [416, 40]}, "slots": {"nb:0": null, "door1:label": "OPEN"}, "fired": ["caption_doubt"]}
	s["player"] = {"position": [500, 144], "carrying": "SHUT"}
	t.ok(SaveManager.write(s), "write succeeds")
	var loaded := SaveManager.load_save()
	t.eq(loaded["revision"], 1, "revision incremented")
	t.eq(loaded["player"]["carrying"], "SHUT", "carrying restored")
	t.eq(loaded["pages"]["ch01_p01"]["slots"]["door1:label"], "OPEN", "slots restored")
	SaveManager.write(loaded)
	t.ok(FileAccess.file_exists(SaveManager.BACKUP_PATH), "previous save kept as backup")
	SaveManager.delete_save()


func test_newer_version_is_never_overwritten(t) -> void:
	SaveManager.delete_save()
	var f := FileAccess.open(SaveManager.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": SaveManager.SCHEMA, "version": 99}))
	f.close()
	t.eq(SaveManager.load_save(), {}, "newer save not loaded")
	t.ok(SaveManager.read_only, "read-only mode")
	t.ok(not SaveManager.write(SaveManager.empty_save()), "write refused")
	t.eq(JSON.parse_string(FileAccess.get_file_as_string(SaveManager.PATH))["version"], 99, "file untouched")
	SaveManager.delete_save()


func test_corrupt_save_falls_back_to_backup(t) -> void:
	SaveManager.delete_save()
	var good := SaveManager.empty_save()
	good["progress"]["page"] = "ch01_p02"
	SaveManager.write(good)
	SaveManager.write(good)   # first write is now the backup
	var f := FileAccess.open(SaveManager.PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var loaded := SaveManager.load_save()
	t.eq(loaded.get("progress", {}).get("page"), "ch01_p02", "backup used")
	SaveManager.delete_save()
	for file in DirAccess.get_files_at("user://"):
		if file.contains(".corrupt-"):
			DirAccess.remove_absolute("user://" + file)
