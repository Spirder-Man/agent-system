---
name: test-ledger
description: 按测试台账指出该跑哪条命令，并在改测后更新最近变更。Use when adding tests, changing tests, asking 怎么测, CI, Playwright, Vitest, xUnit, e2e, or coverage.
---

# 测试怎么跑

打开 [docs/platform/测试台账.md](../../../docs/platform/测试台账.md)。以 `ci.yml` 为 CI 真源，不要引用测试总纲里的历史条数。

## 按改动选命令

- 后端逻辑：`dotnet test Agent1.Tests --filter "Category!=Integration"`
- 前端单元：`cd agent1-web && npx vitest run`
- 集成：本地 PG 齐套后再跑 `Category=Integration`（CI 有临时 PG）
- UI 无后端：`npm run test:e2e`（**不在 CI**）
- 真 API：`npm run test:e2e:real`（健康检查默认 `:5000`）
- 无 GPU 验收：`scripts/demo-compatibility`

改了任何测试文件：在台账「最近变更」加一行（日期、层、一句话）。不要改测试总纲正文。不要改 workflow（冻结）。本阶段不要改评测 JSON / 迁移种子。
