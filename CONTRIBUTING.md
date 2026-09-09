# 如何参与苍卫 / Agent1

公开作品名 **苍卫**。工程与仓库目录仍是 Agent1 / `agent-system`。默认分支 **`master`**。

主约束与 README 相同：**法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。** 改事实通道必须能用测试或脚本证伪，不能只靠生成文本。

**阶段冻结（第一阶段）**：不改规则引擎、双通道、`agent1-web/src/**`、迁移/种子、CI job。允许改文档，以及辅助脚本的默认 API 口（本机 `:5000`）。总闸见 [docs/platform/工程治理.md](docs/platform/工程治理.md)。

## 先读

| 目的 | 文件 |
|------|------|
| 启动与验收 | [README.md](README.md) |
| 提 Bug / 建议 | GitHub：`.github/ISSUE_TEMPLATE/` · Gitee：`.gitee/ISSUE_TEMPLATE/` |
| 漏洞 | [SECURITY.md](SECURITY.md) |
| 讨论规矩 | [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) |
| 模块说明书 | [docs/README.md](docs/README.md) |
| 工程阶段与冻结 | [docs/platform/工程治理.md](docs/platform/工程治理.md) |

镜像仓：[Gitee](https://gitee.com/liuchao_yue/agent-system) · [GitHub](https://github.com/Spirder-Man/agent-system)。任选一边提 Issue / PR 即可，不要同一改动两边各开一发且互不引用。

## 不要提交

- `.env`、口令、JWT、`AUTH_ACCOUNTS_JSON` 真实值
- 国家标准全文、企业内部未公开制度（见 [knowledgebase/README.md](knowledgebase/README.md)）
- GGUF 权重、`docker save` 的 tar
- 演示账号以外的生产身份数据

演示口令 `admin` / `changeme` 只用于本地，不要写进生产。

## 本地检查

无 GPU 验收（与评委路径一致）：

```bash
cp .env.example .env
docker compose -f docker-compose.demo.yml up -d --build
bash scripts/demo-compatibility.sh
# Windows：powershell -ExecutionPolicy Bypass -File scripts/demo-compatibility.ps1
```

改核心库时：

```bash
dotnet test Agent1.Tests --filter "Category!=Integration"
```

改前端时：

```bash
cd agent1-web
npm ci
npx vitest run
```

碰事实通道时优先补：`DeterministicRuleEngineTests`、`ChemicalComplianceToolsTests`、`OutputSanitizerTests`、`RegulationRefs` 相关用例。不要为了「更像通用 Agent」拿掉白名单或违约丢弃。

## 拉取请求

1. 从最新 `master` 开分支。
2. 只改一件事。PR 说明写清：改了什么、怎么验、是否碰到事实通道。
3. 用仓库里的 PR 模板核对清单。
4. 文档不要写超：本仓不是等保测评对象；`gpu-full` 本轮未通过是已知口径，见 [docs/platform/CHANGELOG.md](docs/platform/CHANGELOG.md)。

维护者是小团队，响应可能慢。安全问题按 `SECURITY.md`，不要用公开 Issue 追踪未修复漏洞。
