// Next.js Proxy (formerly middleware) for the API proxy at /v1 (ADR-0012,
// TDD §6). The rewrite in next.config.ts forwards /v1 to the API; this stamps
// each request with the secret only the site and the API share, and the
// browser's IP as the platform saw it, so the API can refuse direct callers
// and rate-limit by the real IP. A browser's own x-margin-* headers are dropped.
import { NextResponse, type NextRequest } from "next/server";

const PROXY_HEADER = "x-margin-proxy";
const CLIENT_IP_HEADER = "x-margin-client-ip";

export function proxy(request: NextRequest): NextResponse {
  const headers = new Headers(request.headers);
  headers.delete(PROXY_HEADER);
  headers.delete(CLIENT_IP_HEADER);
  const secret = process.env.PROXY_SECRET;
  if (secret) {
    headers.set(PROXY_HEADER, secret);
    // Vercel sets X-Forwarded-For to the client IP itself (a browser can't
    // forge it there); the first entry is the client.
    const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || request.headers.get("x-real-ip") || "";
    if (ip) headers.set(CLIENT_IP_HEADER, ip);
  }
  return NextResponse.next({ request: { headers } });
}

export const config = { matcher: "/v1/:path*" };
