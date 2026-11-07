import type { NextConfig } from "next";

// Where the game build lives (TDD §2): a CDN folder in production, so a
// rollback is an env change. Locally it defaults to /game, proxied to the
// static export server (`pnpm game:serve`).
const gameBuildUrl = (process.env.NEXT_PUBLIC_GAME_BUILD_URL ?? "/game").replace(/\/$/, "");
const gameDevOrigin = process.env.GAME_DEV_ORIGIN ?? "http://localhost:8060";
// The API (apps/api). Same-origin /v1 by default, proxied to API_DEV_ORIGIN,
// so its cookies belong to the site and need no CORS.
const apiUrl = (process.env.NEXT_PUBLIC_API_URL ?? "/v1").replace(/\/$/, "");
const apiDevOrigin = process.env.API_DEV_ORIGIN ?? "http://localhost:4000";

const config: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  transpilePackages: ["@the-margin/contracts"],
  env: { NEXT_PUBLIC_GAME_BUILD_URL: gameBuildUrl, NEXT_PUBLIC_API_URL: apiUrl },
  async rewrites() {
    return [
      ...(gameBuildUrl === "/game" ? [{ source: "/game/:path*", destination: `${gameDevOrigin}/:path*` }] : []),
      ...(apiUrl === "/v1" ? [{ source: "/v1/:path*", destination: `${apiDevOrigin}/v1/:path*` }] : []),
    ];
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
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
