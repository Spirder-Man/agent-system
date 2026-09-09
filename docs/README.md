# 文档从哪找

公开作品名 **苍卫**。定位是面向复杂高风险场景的可审计合规；当前验证场是化工园区危化品储存审查。工程名仍是 Agent1 / `agent-system`。

Gitee 网页上搜索 **`os2026`**，就能落到大赛材料。不要在仓库根目录找「大赛」两个字。

文档按**代码模块边界**分目录。每个模块一本说明书（职责、不负责什么、怎么跑、契约、主流程）。历史笔记在 [`_archive/`](_archive/README.md)，不必每次翻。

---

## 按模块

| 模块 | 代码 | 说明书 | 负责 |
|------|------|--------|------|
| platform（跨模块） | （无独立工程） | 见下表「跨模块规范」 | 大赛材料、血谱、测试总纲、等保、CHANGELOG |
| Agent1 | [`../Agent1/`](../Agent1/) | [Agent1/说明书.md](Agent1/说明书.md) | 双通道合规、RAG、规则引擎、编排、审计链 |
| Agent1.Api | [`../Agent1.Api/`](../Agent1.Api/) | [Agent1.Api/说明书.md](Agent1.Api/说明书.md) | REST、JWT、中间件、健康检查 |
| agent1-web | [`../agent1-web/`](../agent1-web/) | [agent1-web/说明书.md](agent1-web/说明书.md) | Vue 页面、契约 `types/api.ts`、MSW |
| e2e | `agent1-web/e2e*` | [e2e/说明书.md](e2e/说明书.md) | Playwright 三档：Mock / 真 API / 大赛录片 |
| Agent1.Tests | [`../Agent1.Tests/`](../Agent1.Tests/) | [Agent1.Tests/说明书.md](Agent1.Tests/说明书.md) | xUnit；旁路 ArchitectureTest、Benchmark |
| db | [`../db/`](../db/)、`init_database.sql` | [db/说明书.md](db/说明书.md) | schema、迁移、危化品种子 |
| knowledgebase | [`../knowledgebase/`](../knowledgebase/) | [knowledgebase/说明书.md](knowledgebase/说明书.md) | 三层语料约定（国标全文不进 Git） |
| models | [`../models/`](../models/) | [models/说明书.md](models/说明书.md) | GGUF 清单（权重不进 Git） |
| infra | compose、`scripts/`、观测栈 | [infra/说明书.md](infra/说明书.md) | Docker、一键部署、GPU 五层测试 |

附属目录（`ssh-runner/`、`ssh-tunnel/`、`task-email/`、`prompts/`、`tools/`）不单独成册，入口见 [infra/说明书.md](infra/说明书.md) §附属。

---

## 先看这些（按你要干什么）

| 你要干什么 | 打开这个 | 备注 |
|------------|----------|------|
| 下载三档源码包 | [platform/release-notes-v0.1.0.md](platform/release-notes-v0.1.0.md) | CPU / GPU / 容器化；[GitHub](https://github.com/Spirder-Man/agent-system/releases/tag/v0.1.0) · [Gitee](https://gitee.com/liuchao_yue/agent-system/releases/tag/v0.1.0) |
| 交作品 / 给评委介绍 | [platform/os2026-作品介绍.md](platform/os2026-作品介绍.md) | 正文。同目录 `.html`、`.pdf` 由 `render_os2026_pdf.py` 从 md 生成 |
| 作品介绍配图 | [platform/os2026-figures/](platform/os2026-figures/) | fig1–fig4 |
| 仓库首页、怎么启动 | 根目录 [README.md](../README.md) | 评委无 GPU 走 demo compose |
| 最近改了什么 | [platform/CHANGELOG.md](platform/CHANGELOG.md) | 版本编年，不写在首页 |
| 等保怎么表述 | [platform/等级保护口径.md](platform/等级保护口径.md) | 参照控制点，不是已测评 |
| 系统怎么连在一起 | [platform/系统血谱.md](platform/系统血谱.md) | L0/L1 数据流；改链路须同批更新 |
| Docker 一键拉起 | [infra/deploy/Docker容器化一键部署.md](infra/deploy/Docker容器化一键部署.md) | 有卡路径 |
| 开源怎么分发、模型不进 Git | [infra/deploy/开源项目分发落地方案.md](infra/deploy/开源项目分发落地方案.md) | 离线 tar 在仓库外 |
| 飞致云 4090 怎么上机 | [infra/deploy/2026-09-07_Featurize4090按量实例操作手册.md](infra/deploy/2026-09-07_Featurize4090按量实例操作手册.md) | 按量实例 |
| GPU 容器修过哪些步骤 | [infra/deploy/2026-09-07_GPU容器化修复步骤.md](infra/deploy/2026-09-07_GPU容器化修复步骤.md) | |
| 测试从哪进 | [platform/测试总纲.md](platform/测试总纲.md) | 分层总入口 |
| 4090 五层两档（quick / full） | [infra/2026-09-07_飞致云五层两档测试说明.md](infra/2026-09-07_飞致云五层两档测试说明.md) | **gpu-full 本轮未通过** |
| gpu-full 对照 | [infra/2026-09-07_飞致云4090_gpu-full深度分析对比报告.md](infra/2026-09-07_飞致云4090_gpu-full深度分析对比报告.md) | |
| GPU 全量校验清单 | [infra/GPU全量校验手册.md](infra/GPU全量校验手册.md) | |
| 3070 实际跑过什么 | [infra/2026-09-06_RTX3070容器实测记录.md](infra/2026-09-06_RTX3070容器实测记录.md) | 文档限定实测 |
| 3070 文档是否写超 | [infra/2026-09-06_3070容器日志核验与文档真实性.md](infra/2026-09-06_3070容器日志核验与文档真实性.md) | |
| 知识库有什么、克隆缺什么 | [../knowledgebase/README.md](../knowledgebase/README.md) | 种子在 SQL；国标全文不进 Git；向量运行时生成 |

演示视频不在 Git 里，在发行版：  
https://gitee.com/liuchao_yue/agent-system/releases/tag/os2026-demo  
作品介绍封面「演示视频」栏写的是同一个地址。

## 交材料前还要在网页上改（仓库改不了）

| 哪里 | 写成 |
|------|------|
| Gitee 仓库设置 → 仓库名称/显示名 | 苍卫 |
| 大赛官网报名表 · 作品中文名 | 苍卫 — 面向复杂高风险场景的可审计合规 Agent |
| 大赛官网报名表 · 演示视频 | https://gitee.com/liuchao_yue/agent-system/releases/tag/os2026-demo |

不要改 Gitee 的仓库路径 `agent-system`（克隆地址保持不变）。

---

## 跨模块规范（`platform/`）

| 文件 | 放什么 |
|------|--------|
| `os2026-作品介绍.*` | **大赛提交正文**（及 html/pdf/配图） |
| `release-notes-v0.1.0.md` | 首次公开源码包说明 |
| `CHANGELOG.md` | 版本编年 |
| `等级保护口径.md` | 等保表述边界 |
| `系统血谱.md` | 数据流地图 |
| `病灶登记表.md` / `同源拷贝联动手册.md` | 血谱配套 |
| `测试总纲.md` | 测试分层总入口 |
| `Agent1 十项核心技术决策深度拆解.md` | 跨模块技术决策 |
| `skills/` | 工程 Skill 模板 |

`_archive/project/` 里还有 6 月以前的全景/差距报告，**不是**大赛提交正文。提交正文只有 `platform/os2026-作品介绍.md`（及 html/pdf）。

---

## 不要在这些地方找大赛介绍

- 仓库根目录（只有 README，没有作品介绍）
- `docs/infra/`、`docs/Agent1.Tests/`（部署和测试，不是介绍正文）
- 文件名含「全景」「差距」「蓝图」的（内部底稿或旧分析）
- [`_archive/`](_archive/README.md)（归档，不当入口）
