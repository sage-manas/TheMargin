import { defineConfig, devices } from "@playwright/test";

const PORT = 8060;

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
  webServer: {
    command: `node ../../infrastructure/scripts/serve-game.mjs ../../apps/game/build/web ${PORT}`,
    port: PORT,
    reuseExistingServer: true,
  },
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
  ],
});
