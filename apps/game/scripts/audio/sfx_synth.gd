class_name SfxSynth
extends RefCounted
## Procedural, license-clean sound effects (ADR-0009). Every sound is built
## from a few primitives — tones, filtered noise, mixing — at boot, so the
## web download carries no audio files at all. The palette is stationery:
## paper slides, peels, stamps, nib scratches.

const RATE := 22050

enum Wave { SINE, TRIANGLE, SQUARE, SAW }


static func build_all() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var s := {}
	s["step"] = _stream(_noise(rng, 0.035, 0.22, 0.16))
	s["hop"] = _stream(_tone(260, 470, 0.09, Wave.TRIANGLE, 0.22))
	s["land"] = _stream(_noise(rng, 0.06, 0.1, 0.32))
	s["grab"] = _stream(_mix(_noise(rng, 0.08, 0.35, 0.2), _tone(170, 210, 0.06, Wave.SINE, 0.15), 0.0))
	s["tick"] = _stream(_mix(_tone(1100, 880, 0.02, Wave.SQUARE, 0.06), _noise(rng, 0.015, 0.6, 0.14), 0.0))
	s["link"] = _stream(_mix(_tone(220, 1000, 0.14, Wave.SINE, 0.3), _sweep(rng, 0.12, 0.08, 0.7, 0.16), 0.0))
	s["unlink"] = _stream(_tone(800, 260, 0.12, Wave.SINE, 0.2))
	s["take"] = _stream(_mix(_sweep(rng, 0.2, 0.04, 0.8, 0.34), _tone(520, 820, 0.1, Wave.TRIANGLE, 0.1), 0.08))
	s["place"] = _stream(_mix(_tone(140, 55, 0.14, Wave.SINE, 0.5), _noise(rng, 0.05, 0.5, 0.3), 0.0))
	s["deny"] = _stream(_mix(_tone(110, 104, 0.18, Wave.SQUARE, 0.1), _tone(117, 110, 0.18, Wave.SQUARE, 0.1), 0.0))
	s["door"] = _stream(_mix(_tone(150, 100, 0.42, Wave.SAW, 0.1), _noise(rng, 0.4, 0.05, 0.12), 0.0))
	s["page_turn"] = _stream(_sweep(rng, 0.75, 0.04, 0.5, 0.34, 0.35))
	s["emote"] = _stream(_tone(660, 900, 0.07, Wave.SINE, 0.14))
	s["shake"] = _stream(_noise(rng, 0.3, 0.07, 0.26))
	# Rubber on paper: three quick back-and-forth strokes of dull noise.
	var rub := PackedFloat32Array()
	for i in 3:
		rub = _mix(rub, _sweep(rng, 0.07, 0.05, 0.18, 0.22), i * 0.08)
	s["rub"] = _stream(rub)
	s["blip"] = _stream(_tone(880, 880, 0.03, Wave.TRIANGLE, 0.1))
	var scratch := PackedFloat32Array()
	for i in 6:
		scratch = _mix(scratch, _sweep(rng, 0.04, 0.3, 0.7, 0.12), i * 0.065)
	s["scratch"] = _stream(scratch)
	var chime := PackedFloat32Array()
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		chime = _mix(chime, _tone(notes[i], notes[i], 0.6, Wave.SINE, 0.16), i * 0.12)
	s["chime"] = _stream(chime)
	return s


## A 4-second seamless room-tone loop: soft paper hiss plus a quiet A/E drone.
## Frequencies complete whole cycles in 4 s so the loop point is click-free.
static func build_ambience() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var n := RATE * 4
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.02 * (rng.randf_range(-1.0, 1.0) - lp)
		var lfo := 0.5 + 0.5 * sin(TAU * 0.25 * t)
		out[i] = lp * 0.5 + sin(TAU * 110.0 * t) * 0.025 * lfo + sin(TAU * 165.0 * t) * 0.015 * (1.0 - lfo)
	var stream := _stream(out)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream


static func _envelope(t: float, dur: float, attack: float) -> float:
	var a := clampf(t / attack, 0.0, 1.0) if attack > 0.0 else 1.0
	var r := 1.0 - t / dur
	return a * r * r


static func _tone(f0: float, f1: float, dur: float, wave: Wave, vol: float, attack := 0.004) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase = fmod(phase + lerpf(f0, f1, t / dur) / RATE, 1.0)
		var v := 0.0
		match wave:
			Wave.SINE:
				v = sin(TAU * phase)
			Wave.TRIANGLE:
				v = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SQUARE:
				v = 1.0 if phase < 0.5 else -1.0
			Wave.SAW:
				v = 2.0 * phase - 1.0
		out[i] = v * vol * _envelope(t, dur, attack)
	return out


## One-pole low-passed noise; `cutoff` is the filter coefficient (0..1).
static func _noise(rng: RandomNumberGenerator, dur: float, cutoff: float, vol: float, attack := 0.002) -> PackedFloat32Array:
	return _sweep(rng, dur, cutoff, cutoff, vol, attack)


## Noise with a filter that opens from c0 to c1: the "peel" of paper.
static func _sweep(rng: RandomNumberGenerator, dur: float, c0: float, c1: float, vol: float, attack := 0.002) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += lerpf(c0, c1, t / dur) * (rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * vol * 2.0 * _envelope(t, dur, attack)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_sec: float) -> PackedFloat32Array:
	var off := int(offset_sec * RATE)
	var out := a.duplicate()
	if out.size() < off + b.size():
		out.resize(off + b.size())
	for i in b.size():
		out[off + i] += b[i]
	return out


static func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
