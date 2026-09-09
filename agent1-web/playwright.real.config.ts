// ============================================================
// Playwright Real E2E — 真后端全链路
//
// 默认: Browser → Vite → 本机/compose API :5000
// 旧 SSH 隧道: 先 npm run tunnel:start，并设 VITE_PROXY_TARGET=http://localhost:15001
// CI 不跑本配置（CI 用 playwright.config.ts + MSW）
// ============================================================

import { defineConfig, devices } from '@playwright/test';

// Docker / 本机 API: PLAYWRIGHT_BASE_URL=http://localhost:8088 VITE_PROXY_TARGET=http://localhost:5000
// 默认代理 :5000。旧 SSH 隧道须设 VITE_PROXY_TARGET=http://localhost:15001
const dockerBaseURL = process.env.PLAYWRIGHT_BASE_URL;
const proxyTarget = process.env.VITE_PROXY_TARGET || 'http://localhost:5000';

export default defineConfig({
  testDir: './e2e-real',
  globalSetup: './e2e-real/global-setup.ts',
  timeout: 120_000, // LLM 真实推理最大等待 2 分钟
  expect: { timeout: 30_000 }, // 单个断言等待最长 30s
  retries: 1, // LLM 推理偶有波动，重试 1 次
  workers: 1, // 串行执行，避免 GPU 并发过载
  forbidOnly: false,

  reporter: [
    ['html', { outputFolder: 'playwright-report-real' }],
    ['json', { outputFile: 'playwright-report-real/results.json' }],
    ['list'],
  ],

  use: {
    baseURL: dockerBaseURL || 'http://localhost:5173',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium-real',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Docker 生产包已由 Nginx 托管时不要再起 Vite（DEV 登录会写假 token）
  webServer: dockerBaseURL
    ? undefined
    : {
        command: 'npx vite --host 0.0.0.0 --port 5173',
        port: 5173,
        reuseExistingServer: true,
        timeout: 30_000,
        env: {
          VITE_ENABLE_MOCK: 'false',
          VITE_PROXY_TARGET: proxyTarget,
        },
      },
});
