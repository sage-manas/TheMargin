class_name Screens
extends RefCounted
## Shared settings menu entries used by the title and pause screens.

const VOLUME_STEPS := [1.0, 0.6, 0.3, 0.0]


static func settings_items() -> Array:
	return [
		{"label": func() -> String: return "SOUND: %d%%" % roundi(Settings.master_volume * 100.0), "action": "volume"},
		{"label": func() -> String: return "REDUCED MOTION: %s" % ("ON" if Settings.reduced_motion else "OFF"), "action": "motion"},
	]


## Handles a settings action; returns true if it was one.
static func handle_setting(action: String) -> bool:
	match action:
		"volume":
			var i := 0
			for k in VOLUME_STEPS.size():
				if absf(VOLUME_STEPS[k] - Settings.master_volume) < 0.05:
					i = k
			Settings.update("masterVolume", VOLUME_STEPS[(i + 1) % VOLUME_STEPS.size()])
			return true
		"motion":
			Settings.update("reducedMotion", not Settings.reduced_motion)
			return true
	return false
