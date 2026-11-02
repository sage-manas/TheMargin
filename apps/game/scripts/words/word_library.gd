class_name WordLibrary
extends RefCounted
## Word definitions loaded from data/words.json (ADR-0004). Objects never
## test word text; they read the category and its parameters.

const PATH := "res://data/words.json"

static var _words := {}


static func load_words(path := PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("words.json is not a JSON object")
		return
	_words = parsed


static func exists(word: String) -> bool:
	return _words.has(word)


static func get_def(word: String) -> Dictionary:
	return _words.get(word, {})


static func category(word: String) -> String:
	return str(get_def(word).get("category", ""))


static func all_words() -> Array:
	return _words.keys()
