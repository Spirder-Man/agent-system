# Agent1 — 化工园区危化品合规审查 AI Agent

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。** LLM 不可用时，门卫 + 责任链 + 规则引擎仍给出可审计结论。

- 仓库：[https://gitee.com/liuchao_yue/agent-system](https://gitee.com/liuchao_yue/agent-system)
- 默认分支：`master`
- 许可证：[LICENSE](LICENSE)（MIT） · 第三方：[NOTICE](NOTICE) · [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- 等级保护口径：[docs/project/等级保护口径.md](docs/project/等级保护口径.md)（参照部分控制点，非已定级备案/测评）

```bash
git clone https://gitee.com/liuchao_yue/agent-system.git
cd agent-system
cp .env.example .env
```

## 评委路径（无 GPU，推荐）

不启动 llama.cpp。PostgreSQL + API 用种子库走规则引擎。

演示账号（仅本地 demo，勿用于生产）：`admin` / `changeme`

```bash
docker compose -f docker-compose.demo.yml up -d --build
bash scripts/demo-compatibility.sh
```

固定验收：查询「甲醇」与「硝酸」能否同库 → 应返回 **禁止同库**，并给出 **GB 15603** 出处（种子精确配对；氯气等同属氧化性气体场景同类）。

保底（无 Docker 时）：

```bash
cd agent1-web && npm install && npm run dev:mock   # 看 UI，不需要后端
dotnet test Agent1.Tests --filter "Category!=Integration"   # 证明可编译可测
```

## 完整 GPU 路径

需要 NVIDIA GPU、`models/*.gguf` 与 [Docker 容器化一键部署](docs/deploy/Docker容器化一键部署.md)。

```bash
docker compose up -d
curl http://localhost:5000/health/live
```

## 数据与版权

**本仓库不包含国家标准全文。** 国标原文须由使用方自备合法副本，放入运行时目录 `knowledgebase/`（已 `.gitignore`）。开源仓只含 schema（[init_database.sql](init_database.sql)）与危化品结构化种子（[db/migrations/002_chemical_knowledge_graph.sql](db/migrations/002_chemical_knowledge_graph.sql)）。

## 架构（摘要）

```
agent1-web (Vue 3)  →  Agent1.Api (ASP.NET Core 8)  →  Agent1 核心库
                                                      双通道：事实=C# / 解释=LLM
PostgreSQL 16 + pgvector    llama.cpp（完整部署）    规则引擎（无 GPU 演示）
```

- 双通道：法规号白名单硬校验，禁止模型发明 GB 编号
- 降级：Function Calling 违约或 LLM 熔断 → 确定性规则引擎
- 审计：SHA256 哈希链；JWT 三角色（admin / auditor / viewer）。参照 GB/T 22239 第三级部分控制点，**不是**已测评的等保对象，见 [等级保护口径](docs/project/等级保护口径.md)

更细的模块清单与 Bug 编年史见 [docs/project/CHANGELOG.md](docs/project/CHANGELOG.md) 与 [docs/](docs/)。

## 本地开发（有 .NET SDK）

```bash
dotnet run --project Agent1.Api    # 默认需 PostgreSQL；无 GPU 时在 .env 设 LLM_OPTIONAL=true
cd agent1-web && npm run dev
```

生产口令只写本机 `.env`，不要提交。必填：`JWT_KEY`（≥32 字符）、`DB_PASSWORD`、`AUTH_ACCOUNTS_JSON`。

## 文档

```
docs/architecture/   架构与系统血谱
docs/deploy/         GPU / Linux 部署
docs/testing/        测试手册
docs/project/        Bug 知识库与 CHANGELOG
```
