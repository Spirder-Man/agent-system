/// <reference types="node" />
import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const user = process.env.E2E_ADMIN_USER || 'admin';
const pass = process.env.E2E_ADMIN_PASSWORD || 'changeme';
const outDir = path.resolve(process.cwd(), '..', 'docs', 'project', 'os2026-figures');

test.describe.configure({ timeout: 180_000 });

test('capture fig3 fig4', async ({ page }) => {
  fs.mkdirSync(outDir, { recursive: true });
  await page.goto('/login');
  await page.locator('input[autocomplete="username"]').fill(user);
  await page.locator('input[autocomplete="current-password"]').fill(pass);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/dashboard/, { timeout: 20_000 });

  await page.goto('/storage/compatibility');
  await page.getByPlaceholder('如：苯').fill('甲醇');
  await page.getByPlaceholder('如：丙酮').fill('硝酸');
  await page.getByRole('button', { name: /检查兼容性/ }).click();
  await page.locator('h2', { hasText: '甲醇 vs 硝酸' }).waitFor({ timeout: 120_000 });
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(outDir, 'fig3-storage.png') });

  await page.goto('/audit');
  await page.getByRole('heading', { name: '审计日志' }).waitFor({ timeout: 15_000 });
  const integrity = page.getByTestId('audit-integrity-btn');
  if (await integrity.isVisible()) {
    await integrity.click();
    await page.waitForTimeout(1500);
  }
  await page.screenshot({ path: path.join(outDir, 'fig4-audit.png') });
});
