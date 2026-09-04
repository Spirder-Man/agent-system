// ============================================================
// Playwright Real GPU E2E 配置 — Agent1 真实后端全链路测试
//
// 全链路: Browser → Vite → SSH Tunnel → .NET API → llama.cpp GPU
//
// 设计原则（对齐双 E2E 分层）:
//   - 主力测试层: 验证 LLM 推理质量 + 工具调用 + 数据一致性
//   - 全局 SSH 隧道: 隧道外部管理（npm run tunnel:start），Playwright 只管 Vite
//   - CI 不跑: 此配置仅本地/手动执行，CI 使用 playwright.config.ts (MSW Mock)
// ============================================================

import { defineConfig, devices } from '@playwright/test';

// Docker 全栈冒烟: PLAYWRIGHT_BASE_URL=http://localhost:8088 VITE_PROXY_TARGET=http://localhost:5000
// 未设置时仍走 Vite :5173 → SSH 隧道 :15001（旧远程 GPU 链路）
const dockerBaseURL = process.env.PLAYWRIGHT_BASE_URL;
const proxyTarget = process.env.VITE_PROXY_TARGET || 'http://localhost:15001';

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
