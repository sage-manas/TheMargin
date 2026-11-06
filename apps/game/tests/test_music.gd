extends RefCounted
## Chapter music (GDD §10): scores are data, loops are seamless, the track
## follows the page's chapter without restarting, and the music ducks while
## the artist intervenes, nesting and never leaking a hold.


func test_note_names(t) -> void:
	t.ok(absf(MusicSynth.note_freq("A4") - 440.0) < 0.01, "A4 is 440 Hz")
	t.ok(absf(MusicSynth.note_freq("C4") - 261.63) < 0.01, "middle C")
	t.ok(absf(MusicSynth.note_freq("A#4") - MusicSynth.note_freq("Bb4")) < 0.001, "sharps and flats agree")
	t.ok(absf(MusicSynth.note_freq("A3") * 2.0 - 440.0) < 0.01, "an octave doubles")
	t.eq(MusicSynth.note_freq("H4"), -1.0, "unknown letter")
	t.eq(MusicSynth.note_freq("A"), -1.0, "missing octave")


func test_pattern_parsing(t) -> void:
	var p := MusicSynth.parse_pattern("A3 - - . | C4+E4 - . -")
	t.eq(p["steps"], 8, "bars are for the reader; every other token is a step")
	t.eq(p["events"].size(), 2, "two notes")
	t.eq(p["events"][0]["steps"], 3, "holds extend a note")
	t.eq(p["events"][1]["step"], 4, "the chord starts after the rest")
	t.eq(p["events"][1]["pitches"], ["C4", "E4"], "chords split on +")
	t.eq(p["events"][1]["steps"], 2, "a hold after a rest stays silent")


func test_tracks_are_valid(t) -> void:
	var defs := MusicSynth.load_defs()
	t.ok(defs.has("ch01"), "chapter 1 has music")
	for id: String in defs:
		t.eq(MusicSynth.validate(defs[id]), [] as Array[String], "track %s is well formed" % id)
	var bad := {"bpm": 80, "bars": 2, "steps_per_bar": 8, "steps_per_beat": 2, "voices": [{"instrument": "kazoo", "pattern": "A4 - H2"}]}
	t.eq(MusicSynth.validate(bad).size(), 3, "unknown instrument, uneven pattern and bad note are all reported")


func test_loop_is_seamless(t) -> void:
	var def: Dictionary = MusicSynth.load_defs()["ch01"]
	var start := Time.get_ticks_msec()
	var m := MusicSynth.from_def("ch01", def)
	m.render_all()
	print("    ch01 rendered in %d ms" % (Time.get_ticks_msec() - start))
	var seconds: float = float(def.bars * def.steps_per_bar) / def.steps_per_beat * 60.0 / def.bpm
	t.eq(m.samples, roundi(seconds * MusicSynth.RATE), "the loop is exactly its bars long")
	t.eq(m.stream().loop_end, m.samples, "the stream loops at the end of the score")
	var buf := m.buffer()
	var peak := 0.0
	var biggest_step := 0.0
	for i in range(1, buf.size()):
		peak = maxf(peak, absf(buf[i]))
		biggest_step = maxf(biggest_step, absf(buf[i] - buf[i - 1]))
	t.ok(peak > 0.1 and peak <= MusicSynth.PEAK + 0.001, "audible and never clipping (%s)" % peak)
	var seam := absf(buf[0] - buf[buf.size() - 1])
	t.ok(seam <= biggest_step, "the loop point is no bigger a jump than the music makes anyway (%s)" % seam)


func test_incremental_build(t) -> void:
	var def: Dictionary = MusicSynth.load_defs()["ch01"]
	var whole := MusicSynth.from_def("ch01", def)
	whole.render_all()
	var sliced := MusicSynth.from_def("ch01", def)
	t.ok(not sliced.step(0), "one tiny slice doesn't finish a track")
	t.ok(sliced.progress() > 0.0 and sliced.progress() < 1.0, "but it makes progress")
	var slices := 1
	while not sliced.step(2000):
		slices += 1
	t.ok(slices > 1, "built over %d slices" % slices)
	var same := true
	for i in range(0, whole.samples, 997):
		same = same and is_equal_approx(whole.buffer()[i], sliced.buffer()[i])
	t.ok(same, "slicing doesn't change the music")


func test_track_follows_the_page(t) -> void:
	t.eq(Audio.track_for_page(ComicPage.load_def("ch01_p01")), "ch01", "story pages play their chapter")
	t.eq(Audio.track_for_page(ComicPage.load_def("sb_mechanics")), "", "sandboxes are quiet")
	t.eq(Audio.track_for_page(ComicPage.load_def("sb_music")), "ch01", "a page can name its track")
	t.eq(Audio.track_for_page({"chapter": "ch01", "music": ""}), "", "or ask for silence")
	for f in DirAccess.get_files_at(ComicPage.DATA_DIR):
		var d := ComicPage.load_def(f.get_basename())
		if d.has("music"):
			t.ok(d.music == "" or Audio.has_track(d.music), "%s names a known track" % d.id)


func test_same_chapter_keeps_playing(t) -> void:
	Audio.build_now("ch01")
	Audio.play_music("ch01")
	await t.frames(2)
	t.eq(Audio.playing_track(), "ch01", "chapter 1 plays")
	var player := Audio.music_player()
	t.ok(player.playing, "on a live player")
	Audio.play_music("ch01")
	await t.frames(2)
	t.ok(Audio.music_player() == player and player.playing, "the next page of the chapter doesn't restart it")
	Audio.stop_music()
	t.eq(Audio.playing_track(), "", "stopping fades to silence")
	await t.frames(roundi(Audio.FADE_SEC * 60.0) + 5)
	t.ok(not player.playing, "and the player stops once it's faded")


func test_ducking_nests(t) -> void:
	Audio.duck_hold()
	Audio.duck_hold()
	Audio.duck_release()
	t.ok(Audio.is_ducking(), "one hold is still down")
	await t.frames(roundi(Audio.DUCK_IN_SEC * 60.0) + 2)
	t.eq(Audio.duck_amount(), 1.0, "fully ducked")
	Audio.duck_release()
	Audio.duck_release()
	t.ok(not Audio.is_ducking(), "released, and extra releases don't go negative")
	await t.frames(roundi(Audio.DUCK_OUT_SEC * 60.0) + 2)
	t.eq(Audio.duck_amount(), 0.0, "back to full")


func test_artist_ducks_the_music(t) -> void:
	var page := ComicPage.new()
	t.root.add_child(page)
	page.build(ComicPage.load_def("sb_music"), {}, {})
	await t.frames(2)
	var artist: Caption = page.captions["artist"]
	var narrator: Caption = page.captions["cap_m1"]
	narrator.write("THE NARRATOR")
	await t.frames(2)
	t.ok(not Audio.is_ducking(), "the narrator doesn't duck the music")
	EventBus.panel_released.emit("m2")
	await t.frames(3)
	t.ok(Audio.is_ducking(), "the artist writing ducks it")
	page.queue_free()
	await t.frames(2)
	t.ok(not Audio.is_ducking(), "a page freed mid-sentence lets go of the duck")
	var cap := Caption.new()
	cap.setup({"id": "a", "at": [0, 0], "style": "artist"})
	t.root.add_child(cap)
	await cap.write("HI")
	t.ok(not Audio.is_ducking(), "the duck ends with the last letter")
	cap.queue_free()


func test_music_volume_setting(t) -> void:
	t.eq(Screens.next_volume(1.0), 0.6, "full steps down")
	t.eq(Screens.next_volume(0.0), 1.0, "silent wraps to full")
	var before := Settings.music_volume
	t.ok(Screens.handle_setting("music"), "MUSIC is a settings action")
	t.eq(Settings.music_volume, Screens.next_volume(before), "it steps the music volume, not the master")
	Settings.update("musicVolume", before)
