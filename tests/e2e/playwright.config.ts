import { defineConfig, devices } from "@playwright/test";

const PORT = 8060;
const WEB_PORT = 3000;
const API_PORT = 4000;
// The API needs Postgres; E2E_CLOUD=0 runs without it (cloud.spec.ts skips).
const cloud = process.env.E2E_CLOUD !== "0";

export default defineConfig({
  testDir: "./specs",
  timeout: 120_000,
  fullyParallel: false,
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: `http://localhost:${PORT}`,
    viewport: { width: 1280, height: 720 },
    trace: "retain-on-failure",
  },
  webServer: [
    {
      command: `node ../../infrastructure/scripts/serve-game.mjs ../../apps/game/build/web ${PORT}`,
      port: PORT,
      reuseExistingServer: true,
    },
    // The site (specs/web.spec.ts). Its /game path proxies to the server above.
    {
      command: "pnpm --filter @the-margin/web build && pnpm --filter @the-margin/web start",
      port: WEB_PORT,
      reuseExistingServer: true,
      timeout: 240_000,
    },
    // The API behind the site's /v1 proxy (specs/cloud.spec.ts), on its own
    // database, migrated and seeded first.
    ...(cloud
      ? [
          {
            command:
              "pnpm --filter @the-margin/api build && pnpm --filter @the-margin/api migrate:deploy && pnpm --filter @the-margin/api seed && pnpm --filter @the-margin/api start",
            port: API_PORT,
            reuseExistingServer: true,
            timeout: 240_000,
            env: {
              ...(process.env as Record<string, string>),
              DATABASE_URL: process.env.E2E_DATABASE_URL ?? "postgresql://margin:margin@localhost:5432/margin_e2e",
              PORT: String(API_PORT),
              WEB_ORIGINS: `http://localhost:${WEB_PORT}`,
              COOKIE_SECURE: "false",
              // Every test signs up from the same IP.
              RATE_LIMIT_REGISTER: "1000",
              RATE_LIMIT_LOGIN: "1000",
            },
          },
        ]
      : []),
  ],
  projects: [
    // WebGL in headless Chromium needs a software GL backend on CI machines.
    { name: "chromium", use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 720 }, launchOptions: { args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"] } } },
    // Headless Firefox on GPU-less Linux has no WebGL2 at all, so CI runs it
    // headed inside xvfb (E2E_HEADED=1) where Mesa's software GL is available;
    // the prefs stop that software renderer from being blocklisted.
    {
      name: "firefox",
      use: {
        ...devices["Desktop Firefox"],
        viewport: { width: 1280, height: 720 },
        headless: process.env.E2E_HEADED !== "1",
        launchOptions: { firefoxUserPrefs: { "webgl.force-enabled": true, "webgl.enable-webgl2": true } },
      },
    },
    // Safari's engine (Risk R3). Opt-in with E2E_WEBKIT=1: it is run on macOS,
    // where WebKit has a real GL backend.
    ...(process.env.E2E_WEBKIT === "1" ? [{ name: "webkit", use: { ...devices["Desktop Safari"], viewport: { width: 1280, height: 720 } } }] : []),
  ],
});
