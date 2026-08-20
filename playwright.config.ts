import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  // Next dev writes route manifests while compiling. Serialize the local
  // integration suite so concurrent first-load compilation cannot corrupt
  // those manifests or make Auth/DB evidence nondeterministic.
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  reporter: "list",
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "retain-on-failure",
  },
  webServer: {
    command: "node scripts/start-local-test-server.mjs",
    url: "http://127.0.0.1:3000/ja",
    reuseExistingServer: false,
    timeout: 120_000,
  },
  projects: [
    { name: "desktop-chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "mobile-chromium", use: { ...devices["Pixel 7"] } },
  ],
});
