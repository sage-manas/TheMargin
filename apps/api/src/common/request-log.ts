// One JSON line per request (TDD §6b), for the platform's log search: no
// query strings, cookies or bodies. The request id comes back as
// x-request-id and is in the error filter's log line for that request.
import { randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";

export type LoggedRequest = Request & { requestId?: string };

export function requestId(req: LoggedRequest, res: Response, next: NextFunction): void {
  const fly = req.headers["fly-request-id"];
  req.requestId = typeof fly === "string" && /^[\w-]{1,64}$/.test(fly) ? fly : randomUUID();
  res.setHeader("x-request-id", req.requestId);
  next();
}

export function requestLog(req: LoggedRequest, res: Response, next: NextFunction): void {
  const start = process.hrtime.bigint();
  res.on("finish", () => {
    const path = req.originalUrl.split("?")[0];
    if (path === "/v1/health") return;
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    const level = res.statusCode >= 500 ? "error" : res.statusCode >= 400 ? "warn" : "info";
    process.stdout.write(JSON.stringify({ t: new Date().toISOString(), level, msg: "request", id: req.requestId, method: req.method, path, status: res.statusCode, ms: Math.round(ms * 10) / 10 }) + "\n");
  });
  next();
}
