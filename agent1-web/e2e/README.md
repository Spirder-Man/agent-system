# E2E（Playwright 三档）

| 档 | 目录 | 命令 | 依赖 |
|----|------|------|------|
| Mock | `e2e/` | `npm run test:e2e` | MSW，无后端 |
| Real | `e2e-real/` | `npm run test:e2e:real` | 真 API / 隧道 |
| Demo | `e2e-demo/` | `npm run demo:record` | Nginx 生产 URL，不要默认 Vite |

完整说明：[docs/e2e/说明书.md](../../docs/e2e/说明书.md)
