// ============================================================
// 工单流 E2E: 登录 → 工单列表 → 详情 → 状态流转（受理/驳回）
//
// 验证：
//   - 工单列表页渲染（问题描述、优先级、状态标签、法规引用）
//   - 点击进入工单详情 → 整改措施/操作日志/可用操作
//   - New → Accepted（受理）乐观更新流转
//   - New → Rejected（驳回）确认框流程
//   - viewer 角色权限（只读，无操作按钮）
//   - 未登录访问重定向
//
// 设计原则：MSW Mock 模式，不依赖后端 GPU/DB
// 状态标签对齐 TICKET_STATUS_LABEL_MAP（新建/已受理/处理中/…）
// ============================================================

import { test, expect } from '@playwright/test';

const ADMIN = { username: 'admin', password: 'admin123' };

test.describe('工单流 — 列表 → 详情 → 状态流转', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.fill('input[autocomplete="username"]', ADMIN.username);
    await page.fill('input[autocomplete="current-password"]', ADMIN.password);
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10_000 });
  });

  // ── 工单列表 ──
  test('应展示工单列表（问题描述 + 优先级 + 状态 + 法规引用 + 操作）', async ({ page }) => {
    const navTickets = page.locator('text=工单管理');
    await expect(navTickets.first()).toBeVisible({ timeout: 5_000 });
    await navTickets.first().click();
    await expect(page).toHaveURL(/\/tickets/, { timeout: 10_000 });

    // 标题与统计（MSW Mock 返回 5 条，全部未关闭）
    // 注意：侧边栏导航也是"工单管理"文本，须用 heading 角色精确定位页标题
    await expect(page.getByRole('heading', { name: '工单管理' })).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('text=共 5 条，未关闭 5 条')).toBeVisible({ timeout: 10_000 });

    // 第一条工单（id=1，New 状态）
    await expect(page.locator('text=苯与丙酮同库储存违规')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('text=Critical')).toBeVisible();
    await expect(page.locator('text=新建')).toBeVisible();
    await expect(page.locator('text=GB 15603-2022 §4.2.2')).toBeVisible();

    // admin 角色可见操作按钮（New → 受理 / 驳回）
    await expect(page.locator('button:has-text("受理")').first()).toBeVisible();
    await expect(page.locator('button:has-text("驳回")').first()).toBeVisible();
  });

  // ── 工单详情 ──
  test('点击工单应进入详情页，展示整改措施与操作日志', async ({ page }) => {
    const navTickets = page.locator('text=工单管理');
    await expect(navTickets.first()).toBeVisible({ timeout: 5_000 });
    await navTickets.first().click();
    await expect(page).toHaveURL(/\/tickets/, { timeout: 10_000 });

    // 点击第一条工单（id=1）
    const firstTicket = page.locator('text=苯与丙酮同库储存违规').first();
    await expect(firstTicket).toBeVisible({ timeout: 10_000 });
    await firstTicket.click();
    await expect(page).toHaveURL(/\/tickets\/1/, { timeout: 5_000 });

    // 详情页核心字段
    await expect(page.locator('text=工单 #1')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('text=立即分库储存')).toBeVisible();
    await expect(page.locator('text=GB 15603-2022 §4.2.2')).toBeVisible();
    await expect(page.locator('text=操作日志: 0 条 · 状态: 进行中')).toBeVisible();

    // 可用操作区（New → 受理/驳回）与状态流转链
    await expect(page.locator('text=可用操作')).toBeVisible();
    await expect(page.locator('button:has-text("受理")')).toBeVisible();
    await expect(page.locator('text=工单跟进')).toBeVisible();
  });

  // ── 状态流转：New → Accepted（受理）──
  test('受理工单应乐观更新为「已受理」', async ({ page }) => {
    const navTickets = page.locator('text=工单管理');
    await expect(navTickets.first()).toBeVisible({ timeout: 5_000 });
    await navTickets.first().click();
    await expect(page).toHaveURL(/\/tickets/, { timeout: 10_000 });

    await expect(page.locator('text=苯与丙酮同库储存违规')).toBeVisible({ timeout: 10_000 });

    // 点击 id=1 行的「受理」按钮（New 状态唯一）
    await page.locator('button:has-text("受理")').first().click();

    // 成功提示 + 状态标签乐观更新（id=1 行内定位：避免与 id=2/4 原有的"已受理"冲突）
    await expect(page.locator('text=受理成功')).toBeVisible({ timeout: 10_000 });
    const row1 = page.locator('tr', { hasText: '苯与丙酮同库储存违规' });
    await expect(row1.getByText('已受理')).toBeVisible({ timeout: 10_000 });
    // 受理后操作变为「开始处理 / 关闭工单」
    await expect(row1.locator('button:has-text("开始处理")')).toBeVisible();
  });

  // ── 状态流转：New → Rejected（驳回，带确认框）──
  test('驳回工单应弹确认框，确认后变为「已驳回」并关闭', async ({ page }) => {
    const navTickets = page.locator('text=工单管理');
    await expect(navTickets.first()).toBeVisible({ timeout: 5_000 });
    await navTickets.first().click();
    await expect(page).toHaveURL(/\/tickets/, { timeout: 10_000 });

    await expect(page.locator('text=苯与丙酮同库储存违规')).toBeVisible({ timeout: 10_000 });

    // 点击「驳回」→ ElMessageBox 确认框
    await page.locator('button:has-text("驳回")').first().click();
    await expect(page.locator('.el-message-box')).toBeVisible({ timeout: 5_000 });
    await expect(page.locator('.el-message-box').getByText('确认驳回工单 #1？')).toBeVisible();

    // 确认驳回
    await page.locator('.el-message-box').getByRole('button', { name: '确认' }).click();

    // 终态：已驳回 + 未关闭数减少（乐观更新 5 → 4）
    await expect(page.locator('text=驳回成功')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('text=已驳回')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('text=共 5 条，未关闭 4 条')).toBeVisible({ timeout: 5_000 });
  });

  // ── 权限：viewer 只读，无操作按钮 ──
  test('viewer 角色在工单列表不应有受理/驳回操作按钮', async ({ page }) => {
    await page.goto('/login');
    await page.context().clearCookies();
    await page.fill('input[autocomplete="username"]', 'viewer');
    await page.fill('input[autocomplete="current-password"]', 'viewer123');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10_000 });

    const navTickets = page.locator('text=工单管理');
    await navTickets.first().click();
    await expect(page).toHaveURL(/\/tickets/, { timeout: 5_000 });

    // 列表数据可见，但操作列不渲染（canOperate = admin/auditor）
    await expect(page.locator('text=苯与丙酮同库储存违规')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('button:has-text("受理")')).toHaveCount(0);
    await expect(page.locator('button:has-text("驳回")')).toHaveCount(0);
  });

  // ── 权限：未登录访问工单页应重定向 ──
  test('未登录访问 /tickets 应重定向到 /login', async ({ page }) => {
    await page.context().clearCookies();
    await page.evaluate(() => localStorage.clear());
    await page.goto('/tickets');
    await expect(page).toHaveURL(/\/login/, { timeout: 5_000 });
  });
});
