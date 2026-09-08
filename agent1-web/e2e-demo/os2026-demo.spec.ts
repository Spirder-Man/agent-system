/// <reference types="node" />
// 仓卫演示片：片头 → 登录一次 → 侧栏核心功能走完 → 片尾。
// 必须打 Nginx 生产包，不要打 Vite。叠字不出现「评委」。

import { test, expect, type Locator, type Page } from '@playwright/test';
import { clickForCamera, hideCard, hold, openNav, showCard, typeForCamera } from './cards';
import { navTestId } from '../src/test-ids';

const REPO = 'https://gitee.com/liuchao_yue/agent-system';
const USER = process.env.E2E_ADMIN_USER || 'admin';
const PASS = process.env.E2E_ADMIN_PASSWORD || 'changeme';
const FORBID = /禁止|严禁|不可|不能同库|禁配|不相容|禁忌/;

test.describe.configure({ timeout: 1_080_000 });

/** 等结果或错误条。不要用泛化 .bg-red-50：应急页「泄漏」选中按钮也是这个类。 */
async function waitResultOrError(page: Page, result: Locator, timeout = 120_000, required = true) {
  const fail = page.locator('div.bg-red-50.border-red-200').first();
  try {
    await expect
      .poll(
        async () => {
          if ((await result.count()) > 0 && (await result.first().isVisible())) return 'ok';
          if (await fail.isVisible()) return 'err';
          return '';
        },
        { timeout },
      )
      .not.toEqual('');
  } catch (err) {
    if (required) throw err;
    console.warn('[demo] 本页结果未齐，继续后面的页面');
  }
  await hold(page, 4500);
}

test('仓卫演示：登录一次，核心功能走完', async ({ page, request }) => {
  const nginx = await request.get('/nginx-health');
  const api = await request.get('/health/live');
  expect(nginx.ok(), 'nginx-health 失败。PLAYWRIGHT_BASE_URL 指向隧道端口（常见 http://localhost:18088）').toBeTruthy();
  expect(api.ok(), 'API /health/live 失败。六个容器还没好。').toBeTruthy();

  const loginProbe = await request.post('/api/Auth/login', {
    data: { username: USER, password: PASS },
  });
  if (loginProbe.status() === 500) {
    throw new Error('登录 HTTP 500。AUTH_ACCOUNTS_JSON 被 compose 吃掉了，按手册 recreate api。');
  }
  expect(loginProbe.ok(), `登录探测失败 HTTP ${loginProbe.status()}，检查 E2E_ADMIN_PASSWORD`).toBeTruthy();

  let sawRealLogin = false;
  page.on('response', (res) => {
    const url = res.url().toLowerCase();
    if (url.includes('/api/auth/login') && res.request().method() === 'POST') {
      sawRealLogin = true;
    }
  });

  await page.goto('/login');
  await expect(page.getByRole('heading', { name: '欢迎登录' })).toBeVisible({ timeout: 15_000 });

  await showCard(page, {
    kicker: 'OS2026 · AI+工业软件',
    title: '仓卫',
    lines: [
      { text: '化工园区危化品合规审查 AI Agent' },
      { text: '法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。' },
      { text: REPO, accent: true },
    ],
    ms: 7000,
  });

  await showCard(page, {
    kicker: '服务检查',
    title: '栈已就绪',
    lines: [
      { text: `Web  /nginx-health    ${nginx.status()} ${nginx.ok() ? 'OK' : 'FAIL'}` },
      { text: `API  /health/live     ${api.status()} ${api.ok() ? 'OK' : 'FAIL'}` },
      { text: '本片打已启动的生产包。无 GPU 时储存禁忌走规则引擎。', muted: true },
    ],
    ms: 5500,
  });
  await hideCard(page);
  await hold(page, 1800);

  await typeForCamera(page.locator('input[autocomplete="username"]'), USER, 160);
  await hold(page, 350);
  await typeForCamera(page.locator('input[autocomplete="current-password"]'), PASS, 120);
  await hold(page, 500);
  await clickForCamera(page, page.locator('button[type="submit"]'));

  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
  expect(sawRealLogin, '没有打到 POST /api/auth/login。不要用 Vite :5173。').toBeTruthy();
  await expect(page.locator('text=化工智能生产运营中心').or(page.locator('h1:has-text("仪表盘")')).first()).toBeVisible(
    { timeout: 15_000 },
  );
  await hold(page, 3500);

  await openNav(page, navTestId('/system'), /\/system/, '系统运维看板');

  await openNav(page, navTestId('/compliance'), /\/compliance$/, '合规检查');
  await typeForCamera(page.getByTestId('compliance-input'), '苯和丙酮能放在同一个仓库吗', 70);
  await hold(page, 400);
  await clickForCamera(page, page.getByTestId('compliance-submit-btn'));
  await waitResultOrError(page, page.getByTestId('compliance-result-panel'));
  const regTab = page.getByTestId('compliance-regulation-tab');
  if (await regTab.isVisible().catch(() => false)) {
    await clickForCamera(page, regTab);
    await hold(page, 3500);
  }

  await openNav(page, navTestId('/compliance/history'), /\/compliance\/history/, '合规历史');
  await openNav(page, navTestId('/eval'), /\/eval/, '合规评测');
  await hold(page, 2000);

  await openNav(page, navTestId('/inspection/plans'), /\/inspection\/plans/, '巡检计划');
  const planLink = page.locator('a.text-blue-700, .bg-white.border.rounded a').first();
  if (await planLink.isVisible().catch(() => false)) {
    await clickForCamera(page, planLink);
    await hold(page, 3000);
  }

  await openNav(page, navTestId('/inspection/rounds'), /\/inspection\/rounds/, '巡检记录');
  await openNav(page, navTestId('/tickets'), /\/tickets/, '工单管理');
  await openNav(page, navTestId('/assets'), /\/assets/, '资产台账');
  await hold(page, 2500);

  await openNav(page, navTestId('/hazard'), /\/hazard/, '危化品查询');
  await typeForCamera(page.getByPlaceholder(/输入化学品名称/), '甲醇', 160);
  await clickForCamera(page, page.getByRole('button', { name: '查询' }));
  await waitResultOrError(page, page.locator('h2', { hasText: '甲醇' }));

  await openNav(page, navTestId('/storage/compatibility'), /\/storage\/compatibility/, '储存兼容性检查');
  await typeForCamera(page.getByPlaceholder('如：苯'), '甲醇', 160);
  await typeForCamera(page.getByPlaceholder('如：丙酮'), '硝酸', 160);
  await clickForCamera(page, page.getByRole('button', { name: /检查兼容性/ }));
  const pair = page.locator('h2', { hasText: '甲醇 vs 硝酸' });
  await expect(pair).toBeVisible({ timeout: 120_000 });
  await expect(page.locator('body')).toContainText('GB 15603', { timeout: 15_000 });
  await expect(page.locator('body')).toContainText(FORBID);
  await pair.scrollIntoViewIfNeeded();
  await hold(page, 8000);

  await openNav(page, navTestId('/chat'), /\/chat/, 'AI 合规助手');
  await typeForCamera(page.getByPlaceholder(/输入合规问题/), '硝酸应该如何储存', 70);
  await clickForCamera(page, page.getByRole('button', { name: '发送' }));
  await expect(page.locator('text=AI 分析中…'))
    .toBeVisible({ timeout: 10_000 })
    .catch(() => undefined);
  await expect(page.locator('text=AI 分析中…')).toBeHidden({ timeout: 120_000 });
  await expect(page.getByRole('button', { name: '清空对话' })).toBeVisible();
  await hold(page, 4500);

  await openNav(page, navTestId('/regulatory'), /\/regulatory/, '法规审计');
  await clickForCamera(page, page.getByRole('button', { name: '审查甲类仓库的消防安全合规性' }));
  await waitResultOrError(page, page.getByRole('heading', { name: '审计结果' }), 120_000, false);

  await openNav(page, navTestId('/emergency'), /\/emergency/, '应急响应');
  await clickForCamera(page, page.getByRole('button', { name: /泄漏/ }));
  await hold(page, 600);
  await clickForCamera(page, page.getByTestId('emergency-submit-btn'));
  await waitResultOrError(page, page.getByTestId('emergency-result'), 120_000, false);

  await openNav(page, navTestId('/knowledgegraph'), /\/knowledgegraph/, '知识图谱');
  await clickForCamera(page, page.getByRole('button', { name: 'GB 15603 关联哪些危化品和园区' }));
  await waitResultOrError(page, page.getByRole('heading', { name: '图谱查询结果' }), 120_000, false);

  await openNav(page, navTestId('/multimodal'), /\/multimodal/, '多模态分析');

  await openNav(page, navTestId('/knowledgebase'), /\/knowledgebase/, '知识库管理');
  await clickForCamera(page, page.getByRole('button', { name: '苯的储存要求是什么' }));
  await waitResultOrError(page, page.locator('text=/召回|耗时|片段/'), 120_000, false);

  await openNav(page, navTestId('/database'), /\/database/, '数据库诊断');
  await openNav(page, navTestId('/diagnostics'), /\/diagnostics/, '工具调用诊断');

  await openNav(page, navTestId('/audit'), /\/audit/, '审计日志');
  const integrityBtn = page.getByTestId('audit-integrity-btn');
  if (await integrityBtn.isVisible()) {
    await clickForCamera(page, integrityBtn);
    await expect(page.locator('body')).toContainText(/完整|未检测到篡改|intact/, { timeout: 15_000 });
    await hold(page, 4000);
  }

  await openNav(page, navTestId('/settings'), /\/settings/, '系统设置');

  await showCard(page, {
    kicker: '开源复现',
    title: '结论不由模型生成',
    lines: [
      { text: '甲醇 × 硝酸 → 禁止同库，出处 GB 15603。' },
      { text: 'clone 后按 README 启动；储存禁忌验收脚本 scripts/demo-compatibility.sh' },
      { text: REPO, accent: true },
    ],
    ms: 7000,
  });
});
