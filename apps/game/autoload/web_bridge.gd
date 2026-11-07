extends Node
## Adapter between the game and its web host (TDD §4). Messages are JSON
## `{v, type, payload}`. The host defines `window.TheMarginBridge` with an
## `onGameMessage(json)` function and an `_inbox` array; we install
## `deliver(json)` for host-to-game messages. Outside the browser, or when no
## host bridge exists, every call is a no-op so the export also runs standalone.

signal cloud_save_received(save: Dictionary)
signal pause_requested
signal resume_requested

const PROTOCOL := 1
const INCOMING := ["LOAD_CLOUD_SAVE", "SET_SETTINGS", "PAUSE", "RESUME", "REQUEST_SAVE"]

var available := false
var _bridge: JavaScriptObject
var _deliver_cb: JavaScriptObject
var _settings_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	_bridge = JavaScriptBridge.get_interface("TheMarginBridge")
	if _bridge == null:
		return
	_deliver_cb = JavaScriptBridge.create_callback(_on_deliver)
	_bridge.deliver = _deliver_cb
	available = true
	Settings.changed.connect(_send_settings)
	var queued: Variant = JavaScriptBridge.eval("JSON.stringify((window.TheMarginBridge._inbox || []).splice(0))", true)
	if queued is String:
		var list: Variant = JSON.parse_string(queued)
		if list is Array:
			for raw: Variant in list:
				_handle(raw if raw is String else JSON.stringify(raw))
	_send_settings()


func send(type: String, payload: Dictionary = {}) -> void:
	if not available:
		return
	_bridge.onGameMessage(JSON.stringify({"v": PROTOCOL, "type": type, "payload": payload}))


## The host mirrors the settings so its settings page shows what the game has.
## Several changes in one frame are sent once.
func _send_settings() -> void:
	if _settings_queued:
		return
	_settings_queued = true
	await get_tree().process_frame
	_settings_queued = false
	send("SETTINGS_UPDATED", {"settings": Settings.to_dict()})


func _on_deliver(args: Array) -> void:
	if args.size() > 0 and args[0] is String:
		_handle(args[0])


func _handle(json: String) -> void:
	var msg: Variant = JSON.parse_string(json)
	if not (msg is Dictionary and int(msg.get("v", 0)) == PROTOCOL and msg.get("type") in INCOMING):
		return
	var payload: Dictionary = msg.get("payload", {}) if msg.get("payload") is Dictionary else {}
	match msg["type"]:
		"LOAD_CLOUD_SAVE":
			var save: Variant = payload.get("save")
			if save is Dictionary and SaveManager.validate(save) == "":
				cloud_save_received.emit(save)
		"SET_SETTINGS":
			var settings: Variant = payload.get("settings")
			if settings is Dictionary:
				Settings.apply_dict(settings)
				Settings.save_settings()
		"PAUSE":
			pause_requested.emit()
		"RESUME":
			resume_requested.emit()
		"REQUEST_SAVE":
			GameState.commit_now()
