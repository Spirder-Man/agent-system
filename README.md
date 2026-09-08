# Agent1 — 化工园区危化品合规审查 AI Agent

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。** LLM 不可用时，门卫 + 责任链 + 规则引擎仍给出可审计结论。

面向化工园区 EHS / 企业安全员与安全管理部的合规审查辅助：两种危化品能否同库、危险类别与安全距离、巡检与工单、操作留痕。不是通用聊天机器人，也不是已交付的园区生产系统。

- 仓库：[https://gitee.com/liuchao_yue/agent-system](https://gitee.com/liuchao_yue/agent-system) · 默认分支 `master`
- 许可证：[LICENSE](LICENSE)（MIT） · 第三方：[NOTICE](NOTICE) · [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- 等级保护口径：[docs/project/等级保护口径.md](docs/project/等级保护口径.md)（参照部分控制点，非已定级备案/测评）

```bash
git clone https://gitee.com/liuchao_yue/agent-system.git
cd agent-system
cp .env.example .env
```

## 启动

演示账号仅本地使用，勿用于生产：`admin` / `changeme`

分发形态与前提条件见 [开源项目分发落地方案](docs/deploy/开源项目分发落地方案.md)。当前默认仍是**本机构建**镜像；不要使用 [docker-compose.release.yml.example](docker-compose.release.yml.example) 去 `pull`（远程仓库尚未发布）。

### 路径 1 — 有网 GPU（推荐）

需要 NVIDIA GPU、Docker Compose V2，以及 `models/` 下的 GGUF（清单见 [models/README.md](models/README.md)）。首次会构建 CUDA llama 镜像，约 10–30 分钟。步骤详见 [Docker 容器化一键部署](docs/deploy/Docker容器化一键部署.md)。

```bash
# 编辑 .env：DB_PASSWORD、JWT_KEY；Windows 无管理员权限时设 WEB_PORT=8088
powershell -File scripts/download-models.ps1   # 或 bash scripts/download-models.sh
# Linux / 有卡:
bash scripts/docker-up.sh gpu
# Windows:
# powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 gpu
curl http://localhost:5000/health/live
```

浏览器打开 `http://localhost`（或 `.env` 的 `WEB_PORT`）。登录后在储存兼容性页查询甲醇与硝酸：应返回禁止同库，并给出 **GB 15603** 出处。

### 路径 2 — 无 GPU 演示

没有 GPU 时用 [docker-compose.demo.yml](docker-compose.demo.yml)：只启动 PostgreSQL 16 + API，不启动 llama.cpp。环境变量 `LLM_OPTIONAL=true`，储存禁忌走确定性规则引擎。

```bash
docker compose -f docker-compose.demo.yml up -d --build
bash scripts/demo-compatibility.sh
cd agent1-web && npm install && npm run dev
```

- API：`http://localhost:5000`（健康检查 `GET /health/live`）
- 前端：Vite 默认 `http://localhost:5173`
- 自检脚本会登录后请求 `POST /api/Compliance/storage/compatibility`，同样应看到禁配与 GB 15603

无 GPU 但需要带 llama.cpp 的完整栈时，叠 [docker-compose.cpu.yml](docker-compose.cpu.yml)（`-ngl 0`，仍要 8B + embed 两件 GGUF）：

```bash
bash scripts/docker-up.sh cpu
# 或: powershell -File scripts/docker-up.ps1 cpu
```

无 Docker 时：

```bash
cd agent1-web && npm install && npm run dev:mock   # 只看 UI，不需要后端
dotnet test Agent1.Tests --filter "Category!=Integration"
```

本机有 .NET SDK、已有 PostgreSQL 时：

```bash
# 无 GPU 时在 .env 设 LLM_OPTIONAL=true
dotnet run --project Agent1.Api
cd agent1-web && npm run dev
```

### 路径 3 — 断网 / 大赛离线包

源码仓**不含** `docker save` 的 `.tar`。断网评委机使用仓库外的 `容器化部署/` 目录（与本 Git 仓并列，不入库）。

- 正式离线包只需 4 个**运行** tar：`agent1-llama-cuda`、`agent-system-api`、`agent1-web`、`pgvector-pg16`。CUDA devel 编译链不要随包分发。
- 离线包里的 `agent1-llama-cuda.tar` **仍不是**打过 `0.1.0` 的正式发布物。源码仓 `Dockerfile.llama*` 钉 llama.cpp **b5512**，这是构建目标，不是「已用本 Dockerfile 在 4090 重编并 `docker save`」。
- **RTX 3070（2026-09-05/06）**：第一波缺 `libllama.so`（exit 127）；第二波 8B 可推理，vision 仍拒 `--mmproj`。见 [3070 实测](docs/testing/2026-09-06_RTX3070容器实测记录.md)。
- **飞致云 RTX 4090 离线包（2026-09-07/08）**：六容器含 `llama-vision` 健康；`gpu-quick` 通过；`gpu-full` 因 L2 缓存未过，**不能写「GPU 全量通过」**。见 [五层两档说明](docs/testing/2026-09-07_飞致云五层两档测试说明.md) 与 [gpu-full 对比报告](docs/testing/2026-09-07_飞致云4090_gpu-full深度分析对比报告.md)。
- 评委无 GPU 走路径 2。有卡复现用仓库外离线包或路径 1，不要把 3070 失败当成当前 4090 状态。
- 模型与语料在离线包的 `cpu/models`、`cpu/knowledgebase`。

## 架构与功能

```
agent1-web (Vue 3)  →  Agent1.Api (ASP.NET Core 8)  →  Agent1 核心库
                                                      双通道：事实=C# / 解释=LLM
PostgreSQL 16 + pgvector    llama.cpp（完整部署）    规则引擎（无 GPU 演示）
```

- **双通道**：法规号、储存禁忌、安全距离由 C# 工具链路给出；大模型只做专业解读与建议。`RegulationRefs` 为法规编号白名单，白名单之外的 GB 号会被删除。
- **降级**：Function Calling 违约、LLM 熔断或 `LLM_OPTIONAL=true` 时，切换 `DeterministicRuleEngine`，结构化结论不依赖生成文本。
- **检索**：中文化工短查询用 NGram + 内存 BM25，向量检索用 pgvector。
- **身份与审计**：JWT 角色 `admin` / `auditor` / `viewer`；操作写入 `audit_logs`，应用层 SHA256 哈希链。

已有界面：登录 `/login`、储存兼容性 `/storage/compatibility`、合规检查 `/compliance`、巡检计划与报告、整改工单、危化品查询、审计日志 `/audit`（当前路由以 admin 为主）。应急与知识图谱页面和接口已存在，深度能力仍在演进，不作生产承诺。

## 边界

- 仅作合规审查辅助，不替代持证安全管理人员的法定职责。
- **本仓库不包含国家标准全文。** 国标原文须由使用方自备合法副本，放入运行时目录 `knowledgebase/`（已 `.gitignore`）。开源仓只含 schema（[init_database.sql](init_database.sql)）与危化品结构化种子（[db/migrations/002_chemical_knowledge_graph.sql](db/migrations/002_chemical_knowledge_graph.sql)）。
- 本仓库不是已定级、已备案或已测评的网络安全等级保护对象，见 [等级保护口径](docs/project/等级保护口径.md)。
- 未对接真实 ERP / WMS / EHS 生产数据。
- 生产口令只写本机 `.env`，不要提交。必填：`JWT_KEY`（不少于 32 字符）、`DB_PASSWORD`、`AUTH_ACCOUNTS_JSON`。

## 文档

```
docs/architecture/   架构与系统血谱
docs/deploy/         GPU / Linux 部署、开源分发落地方案
docs/testing/        测试手册；[3070 实测](docs/testing/2026-09-06_RTX3070容器实测记录.md)；[4090 两档说明](docs/testing/2026-09-07_飞致云五层两档测试说明.md)
docs/project/        等级保护口径、CHANGELOG、作品介绍
```

长期开源分发（镜像仓库 / 模型不进 Git / 离线包）见 [开源项目分发落地方案](docs/deploy/开源项目分发落地方案.md)。
