class_name MusicSynth
extends RefCounted
## Procedural chapter music (ADR-0009, GDD §10). A track in data/music.json
## is a tempo plus a few voices, each a step pattern for one instrument.
## Notes are rendered into a circular buffer, so a tail that rings past the
## loop point wraps to the start and every loop is seamless by construction.
##
## The web export is single-threaded (ADR-0001), so rendering is incremental:
## `step()` renders blocks until a time budget runs out, and the Audio
## autoload calls it once a frame until the track is ready.

## Lower than the SFX rate: the highest partial in any score is ~2.6 kHz, and
## every sample saved is render time saved on the single-threaded web build.
const RATE := 16000
const DATA_PATH := "res://data/music.json"
const BLOCK := 1024
## Release tail (seconds) each instrument rings on after its held steps.
const TAILS := {"felt": 1.2, "pluck": 0.35, "pad": 1.4, "tap": 0.08}
const PEAK := 0.85
const SEMITONES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

var id := ""
var samples := 0
## Notes as [start sample, length in samples, held seconds, frequency, instrument, volume].
var notes: Array = []
var _buf := PackedFloat32Array()
var _cursor := 0
var _stream: AudioStreamWAV


static func load_defs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## "A4" -> 440 Hz. Accepts sharps and flats ("C#5", "Bb3"); returns -1 if invalid.
static func note_freq(name: String) -> float:
	if name.length() < 2 or not SEMITONES.has(name[0]):
		return -1.0
	var semi: int = SEMITONES[name[0]]
	var rest := name.substr(1)
	if rest.begins_with("#"):
		semi += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semi -= 1
		rest = rest.substr(1)
	if not rest.is_valid_int():
		return -1.0
	var midi := (int(rest) + 1) * 12 + semi
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## One token per step: a note or chord ("A3+E4"), "-" holds the previous
## note one more step, "." is a rest, "|" marks bars for the reader only.
## Returns [{step, steps, pitches}] and the pattern's length in steps.
static func parse_pattern(pattern: String) -> Dictionary:
	var events: Array = []
	var step := 0
	var holding := false
	for token in pattern.split(" ", false):
		match token:
			"|":
				continue
			"-":
				if holding:
					events[-1]["steps"] += 1
			".":
				holding = false
			_:
				events.append({"step": step, "steps": 1, "pitches": Array(token.split("+"))})
				holding = true
		step += 1
	return {"events": events, "steps": step}


## Every problem with a track definition, so page and data tests can name them.
static func validate(def: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var total := int(def.get("bars", 0)) * int(def.get("steps_per_bar", 0))
	if float(def.get("bpm", 0)) <= 0.0 or int(def.get("steps_per_beat", 0)) <= 0 or total <= 0:
		errors.append("needs bpm, bars, steps_per_bar and steps_per_beat")
		return errors
	var voices: Array = def.get("voices", [])
	if voices.is_empty():
		errors.append("has no voices")
	for i in voices.size():
		var v: Dictionary = voices[i]
		if not TAILS.has(v.get("instrument", "")):
			errors.append("voice %d: unknown instrument %s" % [i, v.get("instrument")])
		var p := parse_pattern(str(v.get("pattern", "")))
		if p["steps"] == 0 or total % int(p["steps"]) != 0:
			errors.append("voice %d: %d steps don't divide the loop's %d" % [i, p["steps"], total])
		for e: Dictionary in p["events"]:
			for pitch: String in e["pitches"]:
				if note_freq(pitch) < 0.0:
					errors.append("voice %d: bad note %s" % [i, pitch])
	return errors


static func from_def(track_id: String, def: Dictionary) -> MusicSynth:
	var m := MusicSynth.new()
	m.id = track_id
	var step_sec := 60.0 / float(def["bpm"]) / float(def["steps_per_beat"])
	var total := int(def["bars"]) * int(def["steps_per_bar"])
	m.samples = roundi(total * step_sec * RATE)
	m._buf.resize(m.samples)
	for v: Dictionary in def["voices"]:
		var p := parse_pattern(v["pattern"])
		var instrument: String = v["instrument"]
		var vol := float(v.get("volume", 0.2))
		for rep in total / int(p["steps"]):
			for e: Dictionary in p["events"]:
				var held: float = e["steps"] * step_sec
				var length := mini(int((held + TAILS[instrument]) * RATE), m.samples - 1)
				var start := roundi((rep * int(p["steps"]) + int(e["step"])) * step_sec * RATE)
				for pitch: String in e["pitches"]:
					m.notes.append([start, length, held, note_freq(pitch), instrument, vol])
	return m


func is_ready() -> bool:
	return _stream != null


func progress() -> float:
	return float(_cursor) / samples if samples > 0 else 1.0


## Renders blocks until `budget_usec` has passed; true once the loop is ready.
func step(budget_usec: int) -> bool:
	var until := Time.get_ticks_usec() + budget_usec
	while _cursor < samples:
		var to := mini(_cursor + BLOCK, samples)
		_render_block(_cursor, to)
		_cursor = to
		if Time.get_ticks_usec() >= until:
			break
	if _cursor >= samples and _stream == null:
		_finish()
	return is_ready()


func render_all() -> void:
	while not step(1_000_000):
		pass


func stream() -> AudioStreamWAV:
	return _stream


## Raw samples, for tests.
func buffer() -> PackedFloat32Array:
	return _buf


func _render_block(a: int, b: int) -> void:
	for n: Array in notes:
		# A note sounds over [start, start + length) modulo the loop.
		for shift: int in [0, -samples]:
			var s: int = n[0] + shift
			var lo := maxi(a, s)
			var hi := mini(b, s + int(n[1]))
			if lo < hi:
				_render_note(n, lo - s, hi - s, s)


func _render_note(n: Array, from: int, to: int, origin: int) -> void:
	var held: float = n[2]
	var f: float = n[3]
	var vol: float = n[5]
	match n[4]:
		"felt":
			# A felted hammer: soft attack, a warm fundamental, quickly fading overtones.
			for i in range(from, to):
				var t := float(i) / RATE
				var w := TAU * f * t
				var v := sin(w) + 0.3 * sin(2.0 * w) * exp(-t * 4.0) + 0.08 * sin(3.0 * w) * exp(-t * 7.0)
				_buf[origin + i] += v * vol * minf(t / 0.008, 1.0) * exp(-t * 1.6) * _release(t, held, 6.0)
		"pluck":
			for i in range(from, to):
				var t := float(i) / RATE
				var w := TAU * f * t
				var v := sin(w) + 0.5 * sin(2.0 * w) * exp(-t * 9.0) + 0.25 * sin(3.0 * w) * exp(-t * 14.0)
				_buf[origin + i] += v * vol * minf(t / 0.003, 1.0) * exp(-t * 5.0) * _release(t, held, 14.0)
		"pad":
			# Two slightly detuned sines breathing slowly: paper-soft sustain.
			for i in range(from, to):
				var t := float(i) / RATE
				var w := TAU * f * t
				var v := sin(w) + 0.6 * sin(w * 1.004 + 1.3) + 0.15 * sin(2.0 * w)
				var breath := 0.85 + 0.15 * sin(TAU * 0.3 * t)
				_buf[origin + i] += v * vol * breath * minf(t / 0.6, 1.0) * _release(t, held, 2.5)
		"tap":
			# A pencil tapped on the desk: a hashed-noise click over a short thump.
			for i in range(from, to):
				var t := float(i) / RATE
				var noise := fmod(absf(sin(float(origin + i) * 12.9898) * 43758.5453), 1.0) * 2.0 - 1.0
				_buf[origin + i] += (noise * exp(-t * 90.0) * 0.6 + sin(TAU * f * t) * exp(-t * 35.0)) * vol


## 1 while the note is held, then an exponential fade at `rate` per second.
static func _release(t: float, held: float, rate: float) -> float:
	return 1.0 if t < held else exp(-(t - held) * rate)


func _finish() -> void:
	var peak := 0.0
	for s in _buf:
		peak = maxf(peak, absf(s))
	var gain := PEAK / peak if peak > PEAK else 1.0
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in samples:
		bytes.encode_s16(i * 2, int(clampf(_buf[i] * gain, -1.0, 1.0) * 32767.0))
	if gain != 1.0:
		for i in samples:
			_buf[i] *= gain
	_stream = AudioStreamWAV.new()
	_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_stream.mix_rate = RATE
	_stream.stereo = false
	_stream.data = bytes
	_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stream.loop_begin = 0
	_stream.loop_end = samples
