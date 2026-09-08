// 作品介绍配图抓取。允许 Vite，指向本机已启动的前端。
import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:5173';

export default defineConfig({
  testDir: './e2e-demo',
  testMatch: /capture-os2026-figures\.spec\.ts/,
  timeout: 180_000,
  retries: 0,
  workers: 1,
  use: {
    baseURL,
    ...devices['Desktop Chrome'],
    viewport: { width: 1280, height: 800 },
    locale: 'zh-CN',
    headless: true,
  },
  projects: [{ name: 'chromium-capture', use: { ...devices['Desktop Chrome'] } }],
});
