import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:18088';

export default defineConfig({
  testDir: './e2e-demo',
  testMatch: /capture-os2026-figures\.spec\.ts/,
  timeout: 180_000,
  retries: 0,
  workers: 1,
  use: {
    baseURL,
    ...devices['Desktop Chrome'],
    viewport: { width: 1280, height: 720 },
    headless: true,
    video: 'off',
  },
});
