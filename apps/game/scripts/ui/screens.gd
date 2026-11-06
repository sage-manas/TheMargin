class_name Screens
extends RefCounted
## Shared settings menu entries used by the title and pause screens.

const VOLUME_STEPS := [1.0, 0.6, 0.3, 0.0]


static func settings_items() -> Array:
	return [
		{"label": func() -> String: return "SOUND: %d%%" % roundi(Settings.master_volume * 100.0), "action": "volume"},
		{"label": func() -> String: return "MUSIC: %d%%" % roundi(Settings.music_volume * 100.0), "action": "music"},
		{"label": func() -> String: return "REDUCED MOTION: %s" % ("ON" if Settings.reduced_motion else "OFF"), "action": "motion"},
	]


## The volume step after `current`, wrapping from silent back to full.
static func next_volume(current: float) -> float:
	var i := 0
	for k in VOLUME_STEPS.size():
		if absf(VOLUME_STEPS[k] - current) < 0.05:
			i = k
	return VOLUME_STEPS[(i + 1) % VOLUME_STEPS.size()]


## Handles a settings action; returns true if it was one.
static func handle_setting(action: String) -> bool:
	match action:
		"volume":
			Settings.update("masterVolume", next_volume(Settings.master_volume))
			return true
		"music":
			Settings.update("musicVolume", next_volume(Settings.music_volume))
			return true
		"motion":
			Settings.update("reducedMotion", not Settings.reduced_motion)
			return true
	return false
