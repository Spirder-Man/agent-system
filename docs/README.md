# 文档从哪找

公开作品名 **苍卫**。定位是面向复杂高风险场景的可审计合规；当前验证场是化工园区危化品储存审查。工程名仍是 Agent1 / `agent-system`。

Gitee 网页上搜索 **`os2026`**，就能落到大赛材料。不要在仓库根目录找「大赛」两个字。

日常只看下面「先看这些」。其余文件夹是历史笔记，不必每次翻。

---

## 先看这些（按你要干什么）

| 你要干什么 | 打开这个 | 备注 |
|------------|----------|------|
| 交作品 / 给评委介绍 | [project/os2026-作品介绍.md](project/os2026-作品介绍.md) | 正文。同目录还有 `.html`、`.pdf`（PDF 可能比 md 旧一版） |
| 作品介绍配图 | [project/os2026-figures/](project/os2026-figures/) | fig1–fig4 |
| 仓库首页、怎么启动 | 根目录 [README.md](../README.md) | 评委无 GPU 走 demo compose |
| 最近改了什么 | [project/CHANGELOG.md](project/CHANGELOG.md) | 版本编年，不写在首页 |
| 等保怎么表述 | [project/等级保护口径.md](project/等级保护口径.md) | 参照控制点，不是已测评 |
| Docker 一键拉起 | [deploy/Docker容器化一键部署.md](deploy/Docker容器化一键部署.md) | 有卡路径 |
| 开源怎么分发、模型不进 Git | [deploy/开源项目分发落地方案.md](deploy/开源项目分发落地方案.md) | 离线 tar 在仓库外 |
| 飞致云 4090 怎么上机 | [deploy/2026-09-07_Featurize4090按量实例操作手册.md](deploy/2026-09-07_Featurize4090按量实例操作手册.md) | 按量实例 |
| GPU 容器修过哪些步骤 | [deploy/2026-09-07_GPU容器化修复步骤.md](deploy/2026-09-07_GPU容器化修复步骤.md) | |
| 测试从哪进 | [testing/测试总纲.md](testing/测试总纲.md) | 分层总入口 |
| 4090 五层两档（quick / full） | [testing/2026-09-07_飞致云五层两档测试说明.md](testing/2026-09-07_飞致云五层两档测试说明.md) | **gpu-full 本轮未通过** |
| gpu-full 对照 | [testing/2026-09-07_飞致云4090_gpu-full深度分析对比报告.md](testing/2026-09-07_飞致云4090_gpu-full深度分析对比报告.md) | |
| GPU 全量校验清单 | [testing/GPU全量校验手册.md](testing/GPU全量校验手册.md) | |
| 3070 实际跑过什么 | [testing/2026-09-06_RTX3070容器实测记录.md](testing/2026-09-06_RTX3070容器实测记录.md) | 文档限定实测 |
| 3070 文档是否写超 | [project/2026-09-06_3070容器日志核验与文档真实性.md](project/2026-09-06_3070容器日志核验与文档真实性.md) | |
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

## 目录一览（docs/ 下面）

| 文件夹 | 放什么 | 平时要不要进 |
|--------|--------|----------------|
| `project/` | 大赛介绍、CHANGELOG、等保、项目备忘 | **要。大赛材料只在这里，文件名 `os2026-作品介绍.*`** |
| `deploy/` | 部署、飞致云、分发 | 要上机或交离线包时 |
| `testing/` | 测试总纲、GPU 手册、4090/3070 记录 | 要核测试口径时 |
| `architecture/` | 架构、血谱 | 看系统设计时 |
| `数据库化石/` | 表考古、台账 | 查库、核销问题时 |
| `operations/` | 远程启动、联调 | 连真机时 |
| `troubleshooting/` | 历史排障与修复长文 | 对上具体旧 bug 时 |
| `technical-principles/` | 检索/向量等原理 | 学原理时 |
| `frontend/` | 前端设计 | 改 UI 方案时 |
| `analysis/` `articles/` `learning-notes/` `methodology/` `梳理项目/` `工程skill/` | 分析、文章、笔记、skill | 一般不必先看 |
| `_archive/` | 归档旧口径 | 只查历史表述 |
| `docs/` 根上若干 md/html | 断点地图、十项决策等长文 | 按文件名搜，不是大赛入口 |

`project/` 里还有不少 6 月以前的全景/差距报告，**不是**大赛提交正文。提交正文只有 `os2026-作品介绍.md`（及 html/pdf）。

---

## 代码在哪（不是 docs，但常和文档一起找）

| 你要找 | 路径 |
|--------|------|
| 核心库 | `Agent1/` |
| HTTP API | `Agent1.Api/` |
| 前端 | `agent1-web/` |
| 大赛录片脚本 | `agent1-web/e2e-demo/` |
| 后端测试 | `Agent1.Tests/` |
| SQL / 危化品种子 | `db/`、`init_database.sql` |
| 启动、下模型、五层测试、录片 | `scripts/`（`docker-up*`、`download-models*`、`gpu-five-layer.ps1`、`record-os2026-demo.ps1`） |
| 模型清单（权重不入库） | `models/README.md` |
| 语料说明（国标全文不入库） | `knowledgebase/README.md` |

---

## 不要在这些地方找大赛介绍

- 仓库根目录（只有 README，没有作品介绍）
- `docs/deploy/`、`docs/testing/`（部署和测试，不是介绍正文）
- 文件名含「全景」「差距」「蓝图」「豆包」的（内部底稿或旧分析；豆包说明书已不进 Git）
