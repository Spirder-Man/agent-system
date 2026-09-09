# Agent 入口（先读这一页）

公开作品名 **苍卫**。工程名 Agent1 / `agent-system`。人读总闸：[docs/platform/工程治理.md](docs/platform/工程治理.md)。目录讲解：[docs/platform/目录地图.md](docs/platform/目录地图.md)。

提交/推送走个人技能 `review-commit-push`，等用户回复 **通过** 再 `git commit` / `git push`。

## 三个器官

| 目录 | 职责 | 本机口 |
|------|------|--------|
| `agent1-web/` | 前台 Vue | Vite **5173**；Docker Nginx Linux 80 / Windows **8088** |
| `Agent1.Api/` | 传菜口 REST | 主机 **:5000**（容器内 8080） |
| `Agent1/` | 厨房：规则引擎 / RAG / 编排 | 无独立监听口 |

第一阶段 **禁止改**：`Agent1/**`、`Agent1.Api/**`、`agent1-web/src/**`、`init_database.sql`、`db/migrations/**`、`.github/workflows/**`。

## 真源（不要用人脑记）

| 问题 | 打开 |
|------|------|
| 端口会不会挤、哪套能同开 | [docs/platform/运行时端口登记.md](docs/platform/运行时端口登记.md) |
| CI 跑什么、改测改哪 | [docs/platform/测试台账.md](docs/platform/测试台账.md) |
| 每个目录干什么 | [docs/platform/目录地图.md](docs/platform/目录地图.md) |
| 这次学会了什么 | [docs/platform/开发会话纪要/](docs/platform/开发会话纪要/) |
| 仓库可见变更 | [docs/platform/CHANGELOG.md](docs/platform/CHANGELOG.md) |

`docs/platform/测试总纲.md` 与 `docs/platform/skills/` 是历史分层 / 方法底稿，**不是**现网门禁，也 **不是** Cursor Skill。

## 规范脚本（只用这些起栈）

`scripts/docker-up`、`scripts/download-models`、`scripts/demo-compatibility`、`scripts/pack-source-releases`、`scripts/llama-entrypoint`、`scripts/check-coverage`。

- 裸机非规范：`scripts/start_services.sh`（根目录同名文件只转发）、`test_rule_engine.sh`、`test_double_gate.sh`、`quick_test.sh`。
- 历史一次性脚本：`scripts/_legacy/`（**不是入口**）。
- **新脚本只写** `scripts/_scratch/`（gitignore）。收工删除，或提案晋升进 `scripts/README.md`。禁止写在仓库根、桌面、`docs/`。

## 禁止

- 把隧道 `:15000` / `:15001` 或 IDE `:52319` / `:52320` 写成默认 API。
- 同时起全栈 compose 与 `docker-compose.demo.yml`（都要主机 **5000**）。
- 发明第三套默认口；冲突只用 `.env` 已有变量。
- 提交 `.env`、GGUF、国标全文、机房 SSH 工具。
- 新增 Playwright / Docker / Memory MCP。必要 MCP **只有 GitHub**。项目 [`.cursor/mcp.json`](.cursor/mcp.json) 从环境变量 `GITHUB_PERSONAL_ACCESS_TOKEN` 读取，**仓库不存 token**。用户级 `user-github` 若处于 error，在 Cursor Settings → MCP 完成登录。认证失败则用 `gh`（Issue / PR / Actions）。Gitee 用 `git remote origin`。内部飞致云 / SSH 不在本仓。

## 硬规则（各阶段）

1. 法规号、储存禁忌、安全距离由确定性代码给出；大模型只解释和建议。
2. 无 GPU 仍须结构化结论：`docker-compose.demo.yml` + `scripts/demo-compatibility`（甲醇 × 硝酸 → 禁配 + GB 15603）。
3. 改同源拷贝组先查 [docs/platform/同源拷贝联动手册.md](docs/platform/同源拷贝联动手册.md)（第二阶段才允许动）。
