extends Node
## Player settings (user://settings.json) and the input map.
## The input map is built here rather than in project.godot so bindings can
## later be remapped and persisted without editing engine configuration.

signal changed

const PATH := "user://settings.json"
const VERSION := 1

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"interact": [KEY_E],
	"erase": [KEY_X],
	"trace": [KEY_C],
	"panel_mode": [KEY_Q],
	"reset_page": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P],
	"ui_accept_game": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E],
}

var master_volume := 0.8
var sfx_volume := 1.0
var music_volume := 0.6
var reduced_motion := false


func _ready() -> void:
	_register_inputs()
	load_settings()


func _register_inputs() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"masterVolume": master_volume,
		"sfxVolume": sfx_volume,
		"musicVolume": music_volume,
		"reducedMotion": reduced_motion,
	}


## Applies a settings dictionary (from disk or the web host), ignoring invalid fields.
func apply_dict(d: Dictionary) -> void:
	master_volume = _vol(d.get("masterVolume"), master_volume)
	sfx_volume = _vol(d.get("sfxVolume"), sfx_volume)
	music_volume = _vol(d.get("musicVolume"), music_volume)
	if d.get("reducedMotion") is bool:
		reduced_motion = d["reducedMotion"]
	changed.emit()


func _vol(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return fallback


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		changed.emit()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		apply_dict(parsed)
	else:
		changed.emit()


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))
		f.close()


func update(key: String, value: Variant) -> void:
	var d := to_dict()
	d[key] = value
	apply_dict(d)
	save_settings()
