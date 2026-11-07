extends Node
## Sound playback. Owns the synthesized SFX bank, a small voice pool, the
## ambience loop and chapter music. Browsers keep audio suspended until the
## first user gesture; Godot's web runtime resumes the AudioContext on input,
## so nothing here waits.
##
## Music (GDD §10): one loop per chapter from data/music.json, built a slice
## per frame (MusicSynth) and cross-faded when the track changes. It ducks
## while the artist intervenes; ducks nest, so overlapping interventions
## release only when the last one ends.

const VOICES := 10
## Time spent rendering music per frame while a track builds: a sliver
## during play, more while no page is running (the title screen).
const BUILD_BUDGET_USEC := 4000
const IDLE_BUILD_BUDGET_USEC := 12000
const FADE_SEC := 1.5
const DUCK_DB := -12.0
const DUCK_IN_SEC := 0.25
const DUCK_OUT_SEC := 1.2

var _bank := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _ambience: AudioStreamPlayer
var _sfx_bus := -1
var _music_bus := -1

var _music_defs := {}
## Track id -> MusicSynth, built or building.
var _tracks := {}
var _music_players: Array[AudioStreamPlayer] = []
## Per-player fade level (0..1) and where it is heading.
var _fade: Array[float] = [0.0, 0.0]
var _fade_to: Array[float] = [0.0, 0.0]
## Per-player track level from the track's `volume_db`.
var _level: Array[float] = [1.0, 1.0]
var _active := 0
## The track that should be playing ("" for silence) and the one that is.
var _wanted := ""
var _playing := ""
var _duck_holds := 0
var _build_started_msec := {}
var _duck := 0.0


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
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = linear_to_db(0.0001)
		add_child(m)
		_music_players.append(m)
	_music_defs = MusicSynth.load_defs()
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
	AudioServer.set_bus_mute(0, Settings.muted)
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


# --- music -------------------------------------------------------------------

func has_track(track_id: String) -> bool:
	return _music_defs.has(track_id)


## The track a page plays: its `music` field if it has one ("" is silence),
## otherwise its chapter's loop, if that chapter has one.
func track_for_page(def: Dictionary) -> String:
	if def.has("music"):
		return str(def["music"])
	var chapter := str(def.get("chapter", ""))
	return chapter if has_track(chapter) else ""


## Starts building a track ahead of time (the title screen warms up chapter 1).
func prepare_music(track_id: String) -> void:
	if track_id == "" or _tracks.has(track_id):
		return
	if not has_track(track_id):
		push_warning("Unknown music track: %s" % track_id)
		return
	_tracks[track_id] = MusicSynth.from_def(track_id, _music_defs[track_id])
	_build_started_msec[track_id] = Time.get_ticks_msec()


## Cross-fades to `track_id` ("" fades to silence). The same track keeps
## playing untouched, so turning to a page in the same chapter never restarts it.
func play_music(track_id: String) -> void:
	if track_id != "" and not has_track(track_id):
		push_warning("Unknown music track: %s" % track_id)
		track_id = ""
	_wanted = track_id
	prepare_music(track_id)
	_sync_music()


func stop_music() -> void:
	play_music("")


## The track asked for, even while it is still being built.
func music_track() -> String:
	return _wanted


## The track actually audible (or fading in).
func playing_track() -> String:
	return _playing


func is_music_ready(track_id: String) -> bool:
	return _tracks.has(track_id) and (_tracks[track_id] as MusicSynth).is_ready()


## The player carrying the current track (tests and tools).
func music_player() -> AudioStreamPlayer:
	return _music_players[_active]


## Finishes building a track right now instead of a slice per frame (tests and tools).
func build_now(track_id: String) -> void:
	prepare_music(track_id)
	if _tracks.has(track_id):
		(_tracks[track_id] as MusicSynth).render_all()
		_sync_music()


func duck_hold() -> void:
	_duck_holds += 1


func duck_release() -> void:
	_duck_holds = maxi(_duck_holds - 1, 0)


## Ducks for `sec` seconds, nesting with any other hold.
func duck_for(sec: float) -> void:
	duck_hold()
	await get_tree().create_timer(sec, true).timeout
	duck_release()


func is_ducking() -> bool:
	return _duck_holds > 0


## How far the music is ducked right now, 0 (full) to 1 (fully ducked).
func duck_amount() -> float:
	return _duck


func _process(delta: float) -> void:
	for t: MusicSynth in _tracks.values():
		if not t.is_ready():
			t.step(BUILD_BUDGET_USEC if GameState.playing else IDLE_BUILD_BUDGET_USEC)
			if t.is_ready():
				print("Music %s ready after %d ms" % [t.id, Time.get_ticks_msec() - _build_started_msec[t.id]])
				_sync_music()
			break
	_duck = move_toward(_duck, 1.0 if _duck_holds > 0 else 0.0, delta / (DUCK_IN_SEC if _duck_holds > 0 else DUCK_OUT_SEC))
	var duck_gain := lerpf(1.0, db_to_linear(DUCK_DB), _duck)
	for i in 2:
		_fade[i] = move_toward(_fade[i], _fade_to[i], delta / FADE_SEC)
		var p := _music_players[i]
		p.volume_db = linear_to_db(maxf(_fade[i] * duck_gain * _level[i], 0.0001))
		if _fade[i] == 0.0 and _fade_to[i] == 0.0 and p.playing:
			p.stop()


## Brings the players in line with `_wanted` once its track is built.
func _sync_music() -> void:
	if _wanted == _playing:
		return
	if _wanted != "" and not is_music_ready(_wanted):
		return
	_fade_to[_active] = 0.0
	_playing = _wanted
	if _playing == "":
		return
	_active = 1 - _active
	var p := _music_players[_active]
	p.stream = (_tracks[_playing] as MusicSynth).stream()
	_level[_active] = db_to_linear(float(_music_defs[_playing].get("volume_db", 0.0)))
	_fade[_active] = 0.0
	_fade_to[_active] = 1.0
	p.play()
