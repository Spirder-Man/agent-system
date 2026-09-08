/// <reference types="node" />
// Playwright 关掉浏览器后，把最新 webm 拷到 demo-output/os2026-demo.webm

import fs from 'node:fs';
import path from 'node:path';

function walkWebm(dir: string, acc: string[] = []): string[] {
  if (!fs.existsSync(dir)) return acc;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) walkWebm(full, acc);
    else if (ent.name.endsWith('.webm')) acc.push(full);
  }
  return acc;
}

export default async function collectVideo() {
  const cwd = process.cwd();
  const videos = walkWebm(path.join(cwd, 'test-results'));
  if (videos.length === 0) {
    console.error('[demo] 没有找到 video.webm，看 test-results/');
    return;
  }
  videos.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  const destDir = path.join(cwd, 'demo-output');
  fs.mkdirSync(destDir, { recursive: true });
  const dest = path.join(destDir, 'os2026-demo.webm');
  fs.copyFileSync(videos[0], dest);
  const mb = (fs.statSync(dest).size / (1024 * 1024)).toFixed(1);
  console.log(`[demo] 录像已复制 ${dest} (${mb} MB)`);
  console.log(
    '[demo] 交官网前转 MP4：ffmpeg -y -i demo-output/os2026-demo.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart demo-output/os2026-demo.mp4',
  );
}
