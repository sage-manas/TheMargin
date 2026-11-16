// Only the site's proxy may call the API (TDD §6, R10). The proxy stamps each
// request with a shared secret and the browser's IP; without the secret, a
// caller could reach the API directly and forge X-Forwarded-For to dodge the
// rate limits. Off when PROXY_SECRET is unset (local development, tests).
import { timingSafeEqual } from "node:crypto";
import { Inject, Injectable, SetMetadata, type CanActivate, type ExecutionContext } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { ThrottlerGuard } from "@nestjs/throttler";
import type { Request } from "express";
import { CONFIG, type Config } from "../config.js";
import { ApiError } from "../common/errors.js";

export const PROXY_HEADER = "x-margin-proxy";
export const CLIENT_IP_HEADER = "x-margin-client-ip";

/** Routes the platform calls directly (the health check). */
export const Direct = () => SetMetadata("direct", true);

type ProxiedRequest = Request & { clientIp?: string };

@Injectable()
export class ProxyGuard implements CanActivate {
  private readonly secret: Buffer | null;

  constructor(
    private readonly reflector: Reflector,
    @Inject(CONFIG) config: Config,
  ) {
    this.secret = config.proxySecret ? Buffer.from(config.proxySecret) : null;
  }

  canActivate(ctx: ExecutionContext): boolean {
    if (!this.secret) return true;
    if (this.reflector.getAllAndOverride<boolean>("direct", [ctx.getHandler(), ctx.getClass()])) return true;
    const req = ctx.switchToHttp().getRequest<ProxiedRequest>();
    const given = req.headers[PROXY_HEADER];
    if (typeof given !== "string" || given.length !== this.secret.length || !timingSafeEqual(Buffer.from(given), this.secret)) {
      throw new ApiError("FORBIDDEN", "Requests must come through the site.");
    }
    const ip = req.headers[CLIENT_IP_HEADER];
    if (typeof ip === "string" && ip.length > 0 && ip.length <= 64) req.clientIp = ip;
    return true;
  }
}

/** Rate limits key on the proxy's client IP when there is one. */
@Injectable()
export class ClientThrottlerGuard extends ThrottlerGuard {
  protected override async getTracker(req: Record<string, any>): Promise<string> {
    return (req as ProxiedRequest).clientIp ?? (req as ProxiedRequest).ip ?? "unknown";
  }
}
