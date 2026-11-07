// HTTP API v1 request and response shapes (docs/api/API_CONTRACT.md). The
// API validates requests with these; the site's client parses responses.
import { z } from "zod";
import { SaveSchema } from "./save.ts";
import { SettingsSchema } from "./settings.ts";

export const ERROR_CODES = [
  "VALIDATION_FAILED",
  "UNAUTHENTICATED",
  "FORBIDDEN",
  "NOT_FOUND",
  "EMAIL_TAKEN",
  "SAVE_CONFLICT",
  "UNSUPPORTED_SAVE_VERSION",
  "RATE_LIMITED",
  "INTERNAL",
] as const;
export type ErrorCode = (typeof ERROR_CODES)[number];

export const ErrorEnvelopeSchema = z.object({
  error: z.object({ code: z.enum(ERROR_CODES), message: z.string(), details: z.record(z.string(), z.unknown()).default({}) }),
});
export type ErrorEnvelope = z.infer<typeof ErrorEnvelopeSchema>;

const email = z.string().trim().toLowerCase().email().max(254);
export const DisplayNameSchema = z.string().trim().min(1).max(32);

export const RegisterRequestSchema = z.object({
  email,
  // Length is what matters (NIST 800-63B); no composition rules.
  password: z.string().min(10).max(200),
  displayName: DisplayNameSchema,
});
export const LoginRequestSchema = z.object({ email, password: z.string().min(1).max(200) });

export const UserSchema = z.object({ id: z.string().uuid(), email: z.string(), displayName: z.string(), avatar: z.string().nullable() });
export type User = z.infer<typeof UserSchema>;

export const SessionResponseSchema = z.object({ user: UserSchema.nullable(), csrfToken: z.string() });
export type SessionResponse = z.infer<typeof SessionResponseSchema>;

export const ProfilePatchSchema = z
  .object({ displayName: DisplayNameSchema.optional(), avatar: z.string().regex(/^[a-z0-9_-]{1,32}$/).nullable().optional() })
  .refine((p) => Object.keys(p).length > 0, "Nothing to change");

/** The server's revision counts accepted cloud writes; it is not the save's own `revision`. */
export const CloudSaveSchema = z.object({ revision: z.number().int().positive(), save: SaveSchema, updatedAt: z.string() });
export type CloudSave = z.infer<typeof CloudSaveSchema>;

export const PutSaveRequestSchema = z.object({
  /** The cloud revision this save was based on; null when the client has never synced. */
  baseRevision: z.number().int().positive().nullable(),
  save: SaveSchema,
});
export type PutSaveRequest = z.infer<typeof PutSaveRequestSchema>;
export const PutSaveResponseSchema = z.object({ revision: z.number().int().positive() });
/** A conflict loser kept server-side (SAVE_SCHEMA §5); the last 5 are kept. */
export const BackupSaveRequestSchema = z.object({ save: SaveSchema });
export const BACKUPS_KEPT = 5;
/** `details` of a SAVE_CONFLICT error. */
export const SaveConflictDetailsSchema = z.object({ server: CloudSaveSchema });

export const ChapterStatusSchema = z.enum(["locked", "available", "in_progress", "completed"]);
export const ProgressionSchema = z.array(
  z.object({ chapterId: z.string(), title: z.string(), status: ChapterStatusSchema, completedAt: z.string().nullable() }),
);
export type Progression = z.infer<typeof ProgressionSchema>;

export const AchievementListSchema = z.array(
  z.object({ code: z.string(), title: z.string(), description: z.string(), unlockedAt: z.string().nullable() }),
);

export const SettingsResponseSchema = SettingsSchema;
