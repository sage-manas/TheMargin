import { existsSync } from "node:fs";
import type { NextConfig } from "next";

// Where the game build lives (TDD §2, ADR-0012). Deploys copy the export into
// public/game, so it is served by the site itself, same-origin. Without one,
// /game is proxied to the static export server (`pnpm game:serve`). A CDN
// folder can be named with NEXT_PUBLIC_GAME_BUILD_URL instead.
const gameBuildUrl = (process.env.NEXT_PUBLIC_GAME_BUILD_URL ?? "/game").replace(/\/$/, "");
const gameBundled = existsSync(new URL("./public/game/build.json", import.meta.url));
const gameDevOrigin = process.env.GAME_DEV_ORIGIN ?? "http://localhost:8060";
// The API (apps/api) at same-origin /v1, proxied to API_ORIGIN, so its
// cookies belong to the site (vercel.app and fly.dev are different sites).
const apiUrl = (process.env.NEXT_PUBLIC_API_URL ?? "/v1").replace(/\/$/, "");
const apiOrigin = (process.env.API_ORIGIN ?? process.env.API_DEV_ORIGIN ?? "http://localhost:4000").replace(/\/$/, "");

// Content-Security-Policy (TDD §6). Next's hydration payloads
// are inline scripts, so script-src keeps 'unsafe-inline';
// what it rules out is script from anywhere else, and eval: the game runs
// WebAssembly ('wasm-unsafe-eval') and never calls eval (web_bridge.gd).
const originOf = (url: string): string | null => (/^https?:\/\//.test(url) ? new URL(url).origin : null);
const extra = [originOf(gameBuildUrl), originOf(apiUrl)].filter((o): o is string => o !== null);
const dev = process.env.NODE_ENV === "development";
const csp = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'${dev ? " 'unsafe-eval'" : ""} ${extra.join(" ")}`.trim(),
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self'",
  `connect-src 'self' ${extra.join(" ")}${dev ? " ws:" : ""}`.trim(),
  "media-src 'self' blob:",
  "worker-src 'self' blob:",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
].join("; ");

const config: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  transpilePackages: ["@the-margin/contracts"],
  env: { NEXT_PUBLIC_GAME_BUILD_URL: gameBuildUrl, NEXT_PUBLIC_API_URL: apiUrl },
  async rewrites() {
    return [
      ...(gameBuildUrl === "/game" && !gameBundled ? [{ source: "/game/:path*", destination: `${gameDevOrigin}/:path*` }] : []),
      ...(apiUrl === "/v1" ? [{ source: "/v1/:path*", destination: `${apiOrigin}/v1/:path*` }] : []),
    ];
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Content-Security-Policy", value: csp },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
        ],
      },
    ];
  },
};

export default config;
