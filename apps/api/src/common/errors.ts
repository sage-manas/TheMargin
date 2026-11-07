// Every error leaves the API as { error: { code, message, details } }
// (API_CONTRACT.md). Throw ApiError for anything a client should act on.
import { HttpException } from "@nestjs/common";
import type { ErrorCode } from "@the-margin/contracts";

const STATUS: Record<ErrorCode, number> = {
  VALIDATION_FAILED: 400,
  UNAUTHENTICATED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  EMAIL_TAKEN: 409,
  SAVE_CONFLICT: 409,
  UNSUPPORTED_SAVE_VERSION: 422,
  RATE_LIMITED: 429,
  INTERNAL: 500,
};

export class ApiError extends HttpException {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly details: Record<string, unknown> = {},
    status = STATUS[code],
  ) {
    super(message, status);
  }
}

export const unauthenticated = () => new ApiError("UNAUTHENTICATED", "Sign in first.");
export const notFound = (what = "That") => new ApiError("NOT_FOUND", `${what} doesn't exist.`);
