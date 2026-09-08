/// <reference types="node" />
// 只为作品介绍重截 fig3/fig4。不要当演示片。允许 Vite。

import { test, expect } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const USER = process.env.E2E_ADMIN_USER || 'admin';
const PASS = (process.env.E2E_ADMIN_PASSWORD || 'changeme').trim();
const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../docs/project/os2026-figures');

test('capture fig3 storage and fig4 audit', async ({ page, request }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  const live = await request.get('/health/live');
  expect(live.ok(), `health/live ${live.status()}`).toBeTruthy();
  const login = await request.post('/api/Auth/login', {
    data: { username: USER, password: PASS },
  });
  expect(login.ok(), `login HTTP ${login.status()}`).toBeTruthy();
  const body = (await login.json()) as {
    token: string;
    refreshToken: string;
    username: string;
    role: string;
    expiresAt: string;
  };
  await page.addInitScript(
    ({ token, refresh, user }) => {
      localStorage.setItem('auth_token', token);
      localStorage.setItem('auth_refresh', refresh);
      localStorage.setItem('auth_user', user);
    },
    {
      token: body.token,
      refresh: body.refreshToken,
      user: JSON.stringify({ username: body.username, role: body.role, expiresAt: body.expiresAt }),
    },
  );

  await page.goto('/storage/compatibility');
  await expect(page.getByRole('heading', { name: '储存兼容性检查' })).toBeVisible();
  await page.getByPlaceholder('如：苯').fill('甲醇');
  await page.getByPlaceholder('如：丙酮').fill('硝酸');
  await page.getByRole('button', { name: /检查兼容性/ }).click();
  const pair = page.locator('h2', { hasText: '甲醇 vs 硝酸' });
  await expect(pair).toBeVisible({ timeout: 60_000 });
  await expect(page.locator('body')).toContainText(/禁止同库|不得同库|禁配/);
  await expect(page.locator('body')).toContainText('GB 15603');
  await expect(page.locator('body')).not.toContainText('无法给出确定结论');
  await expect(page.locator('body')).not.toContainText('无法得出确定结论');
  await pair.scrollIntoViewIfNeeded();
  await page.screenshot({
    path: path.join(OUT, 'fig3-storage.png'),
    type: 'png',
  });

  await page.goto('/audit');
  const integrityBtn = page.getByTestId('audit-integrity-btn');
  await expect(integrityBtn).toBeVisible({ timeout: 15_000 });
  await integrityBtn.click();
  const repairBtn = page.getByTestId('audit-repair-btn');
  await expect
    .poll(
      async () => {
        const label = ((await integrityBtn.textContent()) || '').trim();
        if (/哈希链完整|intact/i.test(label)) return 'ok';
        if (await repairBtn.isVisible()) return 'repair';
        return '';
      },
      { timeout: 15_000 },
    )
    .not.toEqual('');
  if (await repairBtn.isVisible().catch(() => false)) {
    await repairBtn.click();
  }
  await expect(integrityBtn).toHaveText(/哈希链完整/, { timeout: 20_000 });
  await expect(page.locator('.app-sidebar').getByText('苍卫', { exact: true })).toBeVisible();
  await page.screenshot({
    path: path.join(OUT, 'fig4-audit.png'),
    type: 'png',
  });
});
