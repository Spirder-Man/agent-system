/// <reference types="node" />
// 演示片片头 / 健康检查 / 片尾叠字。挂在真实页面上，不离开 origin。

import { expect, type Locator, type Page } from '@playwright/test';

export type CardLine = { text: string; muted?: boolean; accent?: boolean };

const CARD_ID = 'os2026-demo-card';

export async function hold(page: Page, ms: number) {
  await page.waitForTimeout(ms);
}

export async function showCard(page: Page, opts: { kicker?: string; title: string; lines?: CardLine[]; ms?: number }) {
  await page.evaluate(
    ({ id, kicker, title, lines }) => {
      document.getElementById(id)?.remove();
      const esc = (s: string) =>
        s.replace(
          /[&<>"']/g,
          (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch] as string,
        );
      const el = document.createElement('div');
      el.id = id;
      el.setAttribute('data-demo-card', '1');
      el.style.cssText = [
        'position:fixed',
        'inset:0',
        'z-index:2147483647',
        'background:#0b1f3a',
        'color:#e8eef6',
        'display:flex',
        'flex-direction:column',
        'justify-content:center',
        'padding:64px 88px',
        'font-family:system-ui,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif',
        'letter-spacing:0.02em',
      ].join(';');

      const kickerHtml = kicker
        ? `<div style="font-size:14px;letter-spacing:0.22em;color:#7A96B8;margin-bottom:18px">${esc(kicker)}</div>`
        : '';
      const linesHtml = (lines ?? [])
        .map((line) => {
          const color = line.accent ? '#93C5FD' : line.muted ? '#8aa0b8' : '#c5d4e8';
          const size = line.accent ? '16px' : '17px';
          return `<div style="margin-top:12px;font-size:${size};line-height:1.65;max-width:760px;color:${color}">${esc(line.text)}</div>`;
        })
        .join('');

      el.innerHTML = `${kickerHtml}<div style="font-size:52px;font-weight:700;color:#fff;line-height:1.15">${esc(title)}</div>${linesHtml}`;
      document.documentElement.appendChild(el);
    },
    { id: CARD_ID, kicker: opts.kicker ?? '', title: opts.title, lines: opts.lines ?? [] },
  );
  await hold(page, opts.ms ?? 7000);
}

export async function hideCard(page: Page) {
  await page.evaluate((id) => document.getElementById(id)?.remove(), CARD_ID);
}

export async function clickForCamera(page: Page, locator: Locator) {
  await locator.scrollIntoViewIfNeeded();
  const box = await locator.boundingBox();
  if (box) {
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 14 });
  }
  await locator.click();
}

export async function typeForCamera(locator: Locator, text: string, delay = 150) {
  await locator.click();
  await locator.fill('');
  await locator.pressSequentially(text, { delay });
}

/** 侧栏点一次，等路由和标题出现。 */
export async function openNav(page: Page, testId: string, urlRe: RegExp, heading: string | RegExp) {
  const nav = page.getByTestId(testId);
  await nav.scrollIntoViewIfNeeded();
  await clickForCamera(page, nav);
  await expect(page).toHaveURL(urlRe, { timeout: 10_000 });
  await expect(page.getByRole('heading', { name: heading })).toBeVisible({ timeout: 15_000 });
  await hold(page, 2000);
}
