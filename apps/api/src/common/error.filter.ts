import { Catch, HttpException, Logger, type ArgumentsHost, type ExceptionFilter } from "@nestjs/common";
import type { Response } from "express";
import type { ErrorCode } from "@the-margin/contracts";
import { ApiError } from "./errors.js";

const BY_STATUS: Record<number, [ErrorCode, string]> = {
  400: ["VALIDATION_FAILED", "The request isn't valid."],
  401: ["UNAUTHENTICATED", "Sign in first."],
  403: ["FORBIDDEN", "That isn't allowed."],
  404: ["NOT_FOUND", "That doesn't exist."],
  413: ["VALIDATION_FAILED", "The request is too large."],
  429: ["RATE_LIMITED", "Too many requests. Try again in a minute."],
};

/** Maps every error to the envelope. Internal details are logged, never sent. */
@Catch()
export class ErrorFilter implements ExceptionFilter {
  private readonly log = new Logger("ErrorFilter");

  catch(err: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    if (err instanceof ApiError) {
      res.status(err.getStatus()).json({ error: { code: err.code, message: err.message, details: err.details } });
      return;
    }
    // HttpExceptions from Nest, and body-parser errors (which carry a status).
    const status = err instanceof HttpException ? err.getStatus() : typeof (err as { status?: unknown })?.status === "number" ? (err as { status: number }).status : 500;
    const known = BY_STATUS[status];
    if (known) {
      res.status(status).json({ error: { code: known[0], message: known[1], details: {} } });
      return;
    }
    this.log.error(err instanceof Error ? (err.stack ?? err.message) : String(err));
    res.status(500).json({ error: { code: "INTERNAL", message: "Something went wrong.", details: {} } });
  }
}
