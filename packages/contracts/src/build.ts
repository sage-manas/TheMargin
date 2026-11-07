// build.json, written next to every web export by infrastructure/scripts/godot.mjs.
// The site's launcher reads it to start the engine from any build URL.
import { z } from "zod";

export const BuildManifestSchema = z.object({
  executable: z.string().regex(/^[\w.-]+$/),
  gameVersion: z.string(),
  godotVersion: z.string(),
  fileSizes: z.record(z.string(), z.number().int().nonnegative()),
});

export type BuildManifest = z.infer<typeof BuildManifestSchema>;
