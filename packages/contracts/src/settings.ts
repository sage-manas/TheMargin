// Player settings — mirrors apps/game/autoload/settings.gd (`to_dict`). The
// game owns them (user://settings.json); the site keeps a mirror from
// SETTINGS_UPDATED and sends changes back with SET_SETTINGS.
import { z } from "zod";

export const SETTINGS_VERSION = 1;

const volume = z.number().min(0).max(1);

export const SettingsSchema = z.object({
  version: z.literal(SETTINGS_VERSION),
  masterVolume: volume,
  sfxVolume: volume,
  musicVolume: volume,
  reducedMotion: z.boolean(),
});

// What the site may send: any subset, plus `muted`, which the launcher's mute
// button uses and the game never saves.
export const SettingsPatchSchema = SettingsSchema.omit({ version: true }).partial().extend({ muted: z.boolean().optional() });

export type Settings = z.infer<typeof SettingsSchema>;
export type SettingsPatch = z.infer<typeof SettingsPatchSchema>;

export const DEFAULT_SETTINGS: Settings = {
  version: SETTINGS_VERSION,
  masterVolume: 0.8,
  sfxVolume: 1,
  musicVolume: 0.6,
  reducedMotion: false,
};
