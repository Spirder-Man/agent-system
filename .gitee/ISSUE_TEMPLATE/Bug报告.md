---
name: Bug 报告
about: 复现失败、接口/页面行为与文档不符
title: "[Bug] "
---

安全漏洞请走仓库根目录 `SECURITY.md`，不要用本模板公开贴细节。
不要粘贴 `.env`、JWT、数据库口令、国家标准全文或企业内部制度。

## 现象



## 复现步骤

1. `cp .env.example .env`
2. 
3. 

## 期望结果



## 运行路径

- [ ] 无 GPU 演示（`docker-compose.demo.yml`）
- [ ] CPU（`docker-up cpu`）
- [ ] GPU（`docker-up gpu`）
- [ ] 本机 `dotnet` + 已有 PostgreSQL
- [ ] 仅前端 mock（`npm run dev:mock`）

操作系统：

`GET /health/live`：通过 / 未通过 / 未测

是否与甲醇 × 硝酸储存兼容性有关（期望禁配 + GB 15603）：是 / 否

## 日志或响应摘要（脱敏）



## 提交前

- [ ] 未粘贴密钥、口令、JWT 或生产数据
- [ ] 未粘贴国家标准全文或企业内部未公开制度
- [ ] 已对照 README / `docs/platform/CHANGELOG.md`（例如 gpu-full 本轮未通过是已知口径）
