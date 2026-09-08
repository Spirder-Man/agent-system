// OS2026 演示录像。不起 Vite，不跑 global-setup，失败也不重试。
// 必须设 PLAYWRIGHT_BASE_URL 指向 Nginx（飞致云隧道常见 http://localhost:18088）。

import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:18088';

if (/5173/.test(baseURL) && process.env.DEMO_ALLOW_VITE !== '1') {
  throw new Error(
    `PLAYWRIGHT_BASE_URL=${baseURL} 是 Vite。DEV 登录会写假 token，演示片作废。改成 Nginx 端口，或显式 DEMO_ALLOW_VITE=1。`,
  );
}

export default defineConfig({
  testDir: './e2e-demo',
  testMatch: /os2026-demo\.spec\.ts/,
  globalTeardown: './e2e-demo/collect-video.ts',
  timeout: 1_080_000,
  expect: { timeout: 30_000 },
  retries: 0,
  workers: 1,
  fullyParallel: false,
  forbidOnly: true,
  preserveOutput: 'always',
  outputDir: 'test-results',
  reporter: [['list'], ['html', { outputFolder: 'playwright-report-demo', open: 'never' }]],
  use: {
    baseURL,
    ...devices['Desktop Chrome'],
    viewport: { width: 1280, height: 720 },
    locale: 'zh-CN',
    timezoneId: 'Asia/Shanghai',
    colorScheme: 'light',
    headless: process.env.DEMO_HEADLESS === '1',
    launchOptions: { slowMo: 220 },
    screenshot: 'off',
    video: { mode: 'on', size: { width: 1280, height: 720 } },
    trace: 'off',
    actionTimeout: 20_000,
    navigationTimeout: 30_000,
  },
  projects: [{ name: 'chromium-demo', use: { ...devices['Desktop Chrome'] } }],
});
