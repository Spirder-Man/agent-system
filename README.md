# 苍卫 — 面向复杂高风险场景的可审计合规 Agent

> 法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。
> LLM 不可用时，门卫 + 责任链 + 规则引擎仍给出可审计结论。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

工程名 Agent1 / `agent-system`；当前验证场是化工园区危化品储存审查。

## 项目简介

**苍卫**是一个可私有化部署的合规审查辅助系统，面向化工园区 EHS 与企业安全管理部。现场的问题往往很具体：两种危化品能不能同库、某类物质适用哪些标准编号、设施之间的安全距离够不够、巡检发现的隐患如何留痕闭环。苍卫对这些提问给出可追溯的结构化结论——法规编号、禁忌判定、距离阈值由确定性代码计算，大模型负责把结论翻译成安全员看得懂的解释与建议。

每条结论都能回溯到工具返回值与法规编号出处，操作记录写入带 SHA256 哈希链的审计日志，事后不可篡改。模型不可用或没有 GPU 时，规则引擎照常给出完整结论；整套系统 Docker 一键拉起，数据可以不出企业内网。

它不是通用聊天机器人，也不是已交付的园区生产系统；从克隆仓库到看到第一条「甲醇 × 硝酸 → 禁配，依据 GB 15603」，只需要一条命令。

| 项 | 地址 |
|----|------|
| 代码仓库（Gitee 主仓） | https://gitee.com/liuchao_yue/agent-system |
| GitHub 镜像 | https://github.com/Spirder-Man/agent-system |
| 演示视频（B站） | https://www.bilibili.com/video/BV1ieeu66E1A |
| 设计文档 | [docs/platform/系统血谱.md](docs/platform/系统血谱.md) · [架构导向图](docs/platform/Agent1宏观架构导向图.md) |
| 源码包 | [v0.1.0](docs/platform/release-notes-v0.1.0.md)（容器化 / CPU / GPU 三档，不含模型） |

**技术栈**：Vue 3 · ASP.NET Core 8 · PostgreSQL 16 + pgvector · llama.cpp · Docker Compose · MIT 协议

## 项目结构

```
agent-system/
├── agent1-web/          # 前台：Vue 3 + Vite + Element Plus（Vite :5173 / Docker Nginx）
├── Agent1.Api/          # REST API：路由、JWT 鉴权、健康检查（主机 :5000）
├── Agent1/              # 核心库：规则引擎、RAG 检索、双通道编排、审计哈希链
├── Agent1.Tests/        # xUnit 后端测试（CI 跑非 Integration 类别）
├── knowledgebase/       # RAG 语料目录约定（国标全文不进 Git，种子在 SQL）
├── db/                  # 数据库迁移与 schema；根目录 init_database.sql 供 demo compose 使用
├── Data/                # 评测集 JSON（黄金答案）
├── models/              # GGUF 模型清单与校验和（权重不随 Git 下发）
├── scripts/             # 运维入口：docker-up / download-models / demo-compatibility 等
├── docs/                # 文档：platform/ 跨模块规范，各模块说明书，infra/ 部署记录
├── prompts/             # 历史提示词与角色配置
├── docker-compose*.yml  # GPU 全栈 / CPU / 无 GPU demo / 观测 / staging 编排
├── Dockerfile*          # API、Web、llama.cpp（CUDA / CPU）镜像构建
└── .github/ .gitee/     # 双托管的 Issue 模板、PR 清单与 CI workflow
```

数据流一句话：**浏览器 → agent1-web → Agent1.Api → Agent1 核心库 →（PostgreSQL + pgvector / llama.cpp）**。完整目录讲解见 [docs/platform/目录地图.md](docs/platform/目录地图.md)。

## 启动

需要 NVIDIA GPU、Docker Compose V2，以及 `models/` 下的 GGUF（清单见 [models/README.md](models/README.md)）。首次会构建 CUDA llama 镜像，约 10–30 分钟。步骤详见 [Docker 容器化一键部署](docs/infra/deploy/Docker容器化一键部署.md)。

```bash
git clone https://gitee.com/liuchao_yue/agent-system.git
cd agent-system
cp .env.example .env         # 编辑 DB_PASSWORD、JWT_KEY
powershell -File scripts/download-models.ps1   # 或 bash scripts/download-models.sh
bash scripts/docker-up.sh gpu                  # Windows: powershell -File scripts/docker-up.ps1 gpu
curl http://localhost:5000/health/live
```

浏览器打开 `http://localhost`，演示账号 `admin` / `changeme`（仅本地，勿用于生产）。在储存兼容性页查询甲醇与硝酸：应返回禁止同库，并给出 **GB 15603** 出处。

没有 GPU 时用 `docker compose -f docker-compose.demo.yml up -d --build` 配合 `scripts/demo-compatibility`，储存禁忌直接走确定性规则引擎出结论。

## 架构与功能

```
agent1-web (Vue 3)  →  Agent1.Api (ASP.NET Core 8)  →  Agent1 核心库
                                                      双通道：事实=C# / 解释=LLM
PostgreSQL 16 + pgvector    llama.cpp（完整部署）    规则引擎（无 GPU 演示）
```

- **双通道**：法规号、储存禁忌、安全距离由 C# 工具链路给出；大模型只做专业解读与建议。`RegulationRefs` 为法规编号白名单，白名单之外的 GB 号会被删除。
- **检索算法**：中文化工短查询用 NGram + 内存 BM25 稀疏检索，语义召回用 pgvector 向量检索，混合融合后再经重排序。

## 项目背景

工业现场与合规审查要同时满足三件事：能用自然语言提问、结论必须可追溯、模型或 GPU 挂了仍能给出结构化结果。只把大模型接进对话框，解决不了后两件——编号类、配伍类、阈值类事实如果由模型现场生成，对话记录很难当作业依据。

苍卫的做法是把两者拆开：事实由确定性代码给出，模型只解释和建议。化工园区储存审查被选作验证场，是因为它把上述矛盾压在一条可复现的问题上：两种物质能不能同库、依据哪条标准编号。

## 应用场景

验证场为化工园区危化品储存审查（种子库仿真，可一条命令复现）：

| 场景 | 使用者 | 系统行为 |
|------|--------|----------|
| 储存禁配查询 | EHS / 安全员 | 甲醇 × 硝酸 → 禁配 + GB 15603，结论出自规则引擎 |
| 危险类别 / 危化品查询 | EHS | 查类别与适用标准编号 |
| 合规检查、巡检与工单 | 安全管理部 | 巡检辅助判断、计划/轮次/报告、整改流转 |
| 操作审计 | admin | `audit_logs` + SHA256 哈希链，每条结论可回溯来源 |

同一套「事实不交给模型」的架构可迁移到其他高风险合规场景：作业票审批、仓储布局核查、监管报送辅助。

## 近期进展

- **2026-09-17** — 演示视频上线 B站（BV1ieeu66E1A），设计文档与 README 口径同源统一。
- **2026-09-09** — v0.1.0 三档源码包发布（容器化 / CPU / GPU，不含模型权重）；工程操作系统落地：AGENTS.md 入口、端口与测试真源登记。

## 后续技术更新

- 应急与知识图谱页面从「界面已有」走向深度能力闭环。
- ERP / WMS / EHS 集成接口从预留走向真实数据对接。
- 评测集扩充与规则引擎种子覆盖扩展（更多物质配对与 GB 30000 危险类别）。
- 审计与角色权限细化（auditor / viewer 视角页面）。

## 与我们同行

项目正从「可复现的验证场」走向「可落地的生产系统」，欢迎以下方向的伙伴加入：

| 方向 | 你会做什么 |
|------|-----------|
| C#/.NET 后端 | 规则引擎扩展、ERP/WMS/EHS 集成接口 |
| AI/RAG 工程师 | 混合检索调优、切块策略、评测集建设 |
| Vue 3 前端 | 巡检 / 工单 / 审计页面闭环 |
| 化工 / EHS 领域 | 国标条款入库、储存规则口径校验 |

给 MIT 开源署名 + 完整架构经验 + 可写进简历的开源竞赛与工程治理实践。感兴趣直接开 Issue / PR，或 Gitee 私信联系负责人刘超越。

## 愿景

> **让事实经得起核对，让模型只说真话。**
> 愿每一次「能不能同库」的提问，都有一条可审计的编号在背后。

## 文档

- 按模块找说明书：[docs/README.md](docs/README.md) · 源码包 v0.1.0：[release-notes](docs/platform/release-notes-v0.1.0.md)
- 近期变更：[docs/platform/CHANGELOG.md](docs/platform/CHANGELOG.md) · 工程治理：[docs/platform/工程治理.md](docs/platform/工程治理.md) · [AGENTS.md](AGENTS.md)
- 参与与安全：[CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
