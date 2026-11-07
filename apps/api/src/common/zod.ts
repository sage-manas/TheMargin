import type { z } from "zod";
import { ApiError } from "./errors.js";

/** Parses a request part with a contracts schema, or answers 400 with the issues. */
export function parse<S extends z.ZodTypeAny>(schema: S, input: unknown): z.infer<S> {
  const r = schema.safeParse(input);
  if (!r.success) {
    const issues = r.error.issues.slice(0, 20).map((i) => ({ path: i.path.join("."), message: i.message }));
    throw new ApiError("VALIDATION_FAILED", "The request isn't valid.", { issues });
  }
  return r.data;
}
