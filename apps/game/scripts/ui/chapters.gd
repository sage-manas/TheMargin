class_name Chapters
extends RefCounted
## The chapter list (data/chapters.json, checked against the site's
## catalogue in packages/contracts): numbers and titles for chapter cards.

static var _list: Array = []


static func _all() -> Array:
	if _list.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
		_list = parsed if parsed is Array else []
	return _list


static func info(id: String) -> Dictionary:
	for c: Dictionary in _all():
		if c["id"] == id:
			return c
	return {"id": id, "number": 0, "title": ""}


## "CHAPTER 2: THE BORDER"
static func heading(id: String) -> String:
	var c := info(id)
	return ("CHAPTER %d: %s" % [int(c["number"]), str(c["title"])]).to_upper()
