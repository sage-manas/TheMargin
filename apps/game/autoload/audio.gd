extends Node
## Sound playback. Owns the synthesized SFX bank, a small voice pool, and the
## ambience loop. Browsers keep audio suspended until the first user gesture;
## Godot's web runtime resumes the AudioContext on input, so nothing here waits.

const VOICES := 10

var _bank := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _ambience: AudioStreamPlayer
var _sfx_bus := -1
var _music_bus := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_bus = _ensure_bus("SFX")
	_music_bus = _ensure_bus("Music")
	_bank = SfxSynth.build_all()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	add_child(_ambience)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(maxf(Settings.sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(Settings.music_volume, 0.0001)))


func has_sound(sound: String) -> bool:
	return _bank.has(sound)


func play(sound: String, pitch_jitter := 0.04, volume_db := 0.0) -> void:
	var stream: AudioStream = _bank.get(sound)
	if stream == null:
		push_warning("Unknown sound: %s" % sound)
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func start_ambience() -> void:
	if _ambience.stream == null:
		_ambience.stream = SfxSynth.build_ambience()
	if not _ambience.playing:
		_ambience.play()
