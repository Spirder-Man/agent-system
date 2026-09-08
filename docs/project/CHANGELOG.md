# Changelog

版本编年史已从 README 首页移出，便于评委阅读。

## 近期更新

### 2026-09-08 — 公开作品名

- 大赛公开作品名改为 **苍卫**。工程目录与仓库名仍为 Agent1 / `agent-system`。
- 知识库分层写清：SQL 种子进 Git；虚构园区样例进 `knowledgebase/`；国标全文与向量不进 Git。见 [knowledgebase/README.md](../../knowledgebase/README.md)。
- 作品介绍改为：主题是复杂场景里用确定性技术给出可审计结论；化工储存审查只作为赛道验证场。
- 作品介绍从第 1 章起编；正文改为短段+列表，PDF 行距放宽。
- 团队成员：党嘉韦（前端）。

### 2026-09-07/08 — 飞致云 RTX 4090（离线包运行态）

- **核过的是仓库外离线包 + 自定义镜像**，不是用当前 `Dockerfile.llama`（钉 **b5512**）在 4090 重新编译，也不是本仓后续 C# 改动在 4090 上的正式五层复测。
- `gpu-quick` **通过**。`gpu-full` **不能写全量通过**（`exitCode=1`）：否决项只有 L2 缓存 0.12s；Gate1（含 8083）、L3 44/44、63 条评测完成、识图约 3.4s 为当时记录。见 [五层两档说明](../testing/2026-09-07_飞致云五层两档测试说明.md) 与 [gpu-full 对比报告](../testing/2026-09-07_飞致云4090_gpu-full深度分析对比报告.md)。
- 2026-09-08 自定义镜像拉起后六容器 healthy（含 `llama-vision`）。离线包 vision 已健康，不等于源码钉 b5512 已在 4090 重编冒烟。
- 工作区 `Dockerfile.llama*` 已从 Gitee `4e5b6e8` 的 b5092 改为构建目标 **b5512**。正式 `0.1.0` llama tar 仍须用该 Dockerfile 编过、冒烟后再 `docker save`。

### 2026-09-06 — 3070 容器日志核验（文档限定）

- 对照 RTX 3070 两波部署日志：第一波缺 `libllama.so`（exit 127）；第二波主 LLM/embed 起来，vision 仍 `invalid argument: --mmproj` ×43。实测回填 [3070 容器实测记录](../testing/2026-09-06_RTX3070容器实测记录.md)；次数核验 [文档真实性](./2026-09-06_3070容器日志核验与文档真实性.md)。
- **b5341 / `--mmproj` 已修 = 本机工作区目标，不是 09-05/06 实测结论。** Gitee `4e5b6e8` 只打进共享库，Dockerfile 仍钉 b5092。有卡机用新镜像冒烟前，不要把「已修」写进发布说明。
- GPU 全量校验手册结果表已按该日志回填，**总判定失败**（8083 未通；L0/L1/L3/L4 评测未跑）。
- 修复顺序（L11 优先，尚未在 3070 验证）：compose 已补 `-ub 2048` 与 `002`/`004`–`006` 挂载。步骤见 [GPU 容器化修复步骤](../deploy/2026-09-07_GPU容器化修复步骤.md)。

### 2026-09-05 — llama.cpp b5092 → b5341（工作区；未在 3070 冒烟）

- **钉 b5341（本机未提交）**：CUDA / CPU `Dockerfile.llama*` 拟与 GPU 离线包同源。上游 #12898（约 b5331）起 `llama-server` **可以**认识 `--mmproj`。3070 于 2026-09-05/06 跑的仍是旧二进制，8083 仍报 `invalid argument: --mmproj`，**不能写成已修**。CPU 运行镜像改为 `find` 收集 `.so`（与 `4e5b6e8` 同一层，第二波已证实能挡住 exit 127）。
- **显存自动探测**：compose 默认仍 `ENABLE_VISION_OCR=true`（24GB 生产零改动）。`scripts/docker-up` 在变量未显式设置时：显存 ≥20GB 开视觉，否则跳过 `llama-vision`。`.env` 写 `true|false` 可强制覆盖。

### v4.8 之后已合入主干（README 此前未写全，截至 2026-08-31）

> 版本号仍标 **v4.8**，下列能力已在 `master` 合入，功能全景已同步。不新编 v4.9。

- **认知漂移监测 phase 1–3**：锚点注册表 / 测量链路 / 探针调度器 + `DriftController`
- **Qwen2.5-VL**：扫描件 PDF OCR 回退管线；视觉服务端口 8083（与精排 8082 分离）
- **知识管线**：Bug-039/041/042/043 检索与入库修复；embedding `-b/-ub 2048` 修超长 OCR 条款块；乱码闸门可证伪锚点
- **数据库台账批次**：安全规则（王水等）/ 记忆空心化与 Upsert / 测试误删防护等已核销条目见 [全量问题台账](docs/数据库化石/全量问题台账.md)（核销率与剩余 P1 #10 水印块以台账为准）

### v4.8 — 十项问题分批修复 + 系统血谱方法论落地（2026-07-28）

> 源自一次远程运行日志的十项问题清单（2P1 + 5P2 + 3P3），逐项日志实锤归因后分批修复，全程零概率性手段。详见 [十项问题多维度深度分析报告](docs/analysis/2026-07-28_十项问题多维度深度分析报告.md)。

- **#1 Bug-035（P0）SQLite 兜底库静默降级**：`SplitSqlStatements` 天真 `Split(';')` 被 `GROUP_CONCAT(..., '; ')` 字面量击穿——删除拆分器改整段 `ExecuteNonQuery`（原生支持多语句）；catch 不再置 `_initialized=true`，降级可重试可观测。提炼警示模式 W24「手写解析器低估目标语法复杂度」
- **#2 幻觉法规号硬校验**：`OutputValidator` 白名单硬校验——库外 GB 编号替换为【待核实】标注（不删除、不打分）；白名单取三源并集（regulation_versions 种子 ∪ 知识图谱 ∪ 硬编码字典源）防误杀
- **#3 安全距离设施对补全**：按 GB 50016/50160 表格补全设施对（每条带条款出处），SQLite 种子/PG 迁移/测试桩三处同源拷贝同步
- **#4 Dashboard 扫描异步化**：同步阻塞 521s → `ScanProgressService` 202+scanId 后台任务 + GET 轮询 + 并发 409，前端 2s 轮询；复用既有进度回调零新增埋点
- **#5 知识库乱码闸门**：新增 `GarbledTextDetector` 三规则守门员，5 处入库循环过滤 + WRN 留痕（存量乱码块待知识库重建清除）
- **#6 告警收件人**：本地配置实为完备（调研勘误），仅补前端空值防御；远程 `.env` 补配待实例开机
- **#7 缓存预热双格式兼容**：`WarmupFromEvalSet` wrapper 对象优先 + 数组兜底，与 EvalEngine 同构
- **#8 quality-rules.json 构建分发**：根因是 csproj 缺 Content 分发项（非文件缺失），补分发后启动 WRN 消除
- **#9 CS0618 警告收敛**：`AgentDialog` 私有字段承载内部状态 + Obsolete 属性只读透出——CS0618 14→0，警告对外部调用者保留
- **#10 GetCurrentTime 取舍标注**：领域化 system prompt 下时间类工具低触发是预期副作用，拒绝概率性调 prompt，文档标注取舍理由（不改代码）
- **系统血谱方法论**：新增 [系统血谱](docs/architecture/系统血谱.md)（L0 大动脉/L1 静脉持久主图 + 同源拷贝登记表 + 病灶登记表）与 `system-blood-map` 技能——代码变更前先输出影响血管清单，改完回写主图
- **最终回归**：三项目 0 error；后端 1565 测试 NEW_FAILURES=0；前端 vitest 350/356（6 失败实锤为既有问题）+ vue-tsc 通过

### v4.7 — 架构收敛：降级路径统一为门卫+责任链+规则引擎（2026-07-27）

- **Bug-033 架构收敛**：4 条 LLM 零工具调用降级路径（E1正则猜测/FC=Required违约→BuildNoResult/熔断器打开→规则引擎/"生成失败"→规则引擎）统一收敛为单一入口 `TryFallbackToRuleEngine`
  - **DeterministicRuleEngine 重构**：新增 `IComplianceQueryHandler` 接口 + `ChemicalSignalGate` 信号词门卫（18 个化工关键词粗筛）+ 3 个 Handler 类（StorageCompatibility/HazardCategory/SafetyDistance）→ `_handlers` 责任链 → 首个命中返回
  - **AgentDialog 三调用点统一**：ExecuteChemicalComplianceAsync/ExecuteEvalInternalAsync/ExecuteEvalPerCaseAsync → 全部替换为 TryFallbackToRuleEngine
  - **LlmService 清理**：删除 `TryKeywordToolFallbackAsync` 方法（40 行 3 个正则模式，伪工程方案）
- **长期可演进策略**：门卫拦无关输入（"蜘蛛侠"不触发 handler），责任链匹配具体场景，新增合规场景（如应急响应）仅需新增一个 `IComplianceQueryHandler` 实现 + 在 `_handlers` 列表加一行注册，核心方法 `TryHandleComplianceQuery` 永不再改
- **根因方法论**：Git 历史分析发现同一开发者在 35 天内分 4 次 commit 加入互不感知的降级路径，根因是"LLM 完全宕机"和"LLM 未调用工具"的心理边界分裂。提炼出「设计理据追问法」— 看到 AI 生成的代码时问 3 个问题：为什么选这个方案？暴露了什么认知盲区？应该在哪个环节纠正？
- **Bug 知识库**：新增 Bug-033 完整记录 + W22 系统弱点 + 7 节点思维链路复盘
- 详见 [Bug知识库](docs/project/Bug知识库.md) Bug-033

### v4.6 — 工程侧7项缺陷修复：幻觉防护 + 别名归一化 + 评测准确性（2026-07-25）

- **E1 FC关键字兜底机制（v4.7 已重构为门卫+责任链架构）**：原LLM零工具调用时按关键词正则自动触发 ChemicalComplianceTools，见下方 v4.7 架构收敛
- **E2 Prompt反幻觉指令强化**：将 `[REGULATIONS:]` 标签引用改为自然语言「所见即所得」式指令，明确GB编号相似≠相同规则
- **E3 法规编号精确匹配**：`IsRegulationAllowed` 删除 Contains 模糊匹配，仅保留 Equals；`NormalizeRegNumber` 新增年份后缀剥离
- **E4 RAG检索来源去重**：重排序后增加来源去重——每源文档最多2条，至少3个不同来源，防止单一文档垄断 topK
- **E5 Level4幻觉检测漏报修复**：检测到幻觉后更新 `ConclusionReasons[0].Passed=false`，消除 41 条漏报
- **E6 白名单双路径不一致修复**：`ExtractGbNumbers` 降级为 else 兜底，仅无 `[REGULATIONS:]` 标签时使用
- **E7 化学品名称归一化重构**：删除冗余的 `SubstanceAliasMap` 硬编码字典（14条映射：13条冗余 + 1条错误「盐酸→氯化氢」），统一归一化至 `ChemicalSubstanceDatabase.Lookup`——新增别名只需在数据类 `Aliases` 字段加一行，自动注册

### v4.5 — E2E 三层契约架构落地 + 提交钩子环境修复（2026-07-21）

- **E2E 三层契约架构**：Test-ID 契约（`test-ids.ts` 单一真值源 + CI 校验）/ 数据契约（`data-manifest.ts` 声明式依赖 + 自动补种）/ 质量基线契约（`baseline.json` + `llm-assertions.ts` 可演进断言）
- **双 E2E 分层**：`playwright.config.ts` MSW Mock CI 门禁 + `playwright.real.config.ts` 真实 GPU 全链路（经 SSH 隧道）；新增 `test:e2e:real`、`tunnel:start/stop`、`health:check` 等 npm 脚本
- **契约消费重构**：14 个 e2e/e2e-real spec 改用 `getByTestId()` 精确定位，6 个 Vue 组件 data-testid 规范化，消除 strict mode 冲突
- **提交钩子修复**：补齐缺失的 ESLint(flat config)/Prettier 依赖与配置，`pre-commit` + lint-staged 恢复可用
- **`.gitignore` 收敛**：忽略 `playwright-report/`、`test-results/`、`eval_reports/` 等测试产物与含令牌的本地脚本

### v4.4 — Bug-032 v2 回马枪：防御代码位置正确性（2026-07-20）

- **Bug-032 v2**：FC=Required 违约检测从 `HasAnyToolResult` 之后提升为独立最高优先级闸门
  - v1 (7/18, `5dcf4f2`)：`toolCalls==0` 检查放在 `else` 分支内，被 `HasAnyToolResult==true` 时提前 return 绕过
  - v2 (7/20, `94e4818`)：`toolCalls==0` 提升为 `HasAnyToolResult` 之前的独立闸门，无条件拦截 FC 违约
  - 远程 3 轮扫描验证：v1 拦截 0 次，v2 拦截 10 次（Prometheus: `agent1_fc_contract_violation_total=10`）
- **编译缓存陷阱**：`dotnet run` 增量编译可能不反映源码变更 → 远程部署关键修复需 `rm -rf bin/obj && dotnet build --force`
- **Bug 知识库**：新增 N8 思维节点，记录防御代码"位置正确性"与"逻辑正确性"双维度分析方法论

### v4.3 — P0 Bug 修复批次（2026-07-18）

- **Bug-031**：审计哈希链彻底修复 — 移除 createTime 依赖 + 启动自愈
- **Bug-032**：FC=Required 违约兜底 — toolCalls==0 时丢弃 LLM 废话，走确定性拒绝模板（v2 回马枪见 v4.4）
- **IsDirty 阈值**：短文本拦截 `< 20` → `< 5`，H166 模板不再误拦截
- **IntentRouter**：新增 25 个关键词，覆盖化学品名/仓库/消防/安全术语
- **LLM 扫描预检**：`CheckLlmHealthAsync()` 3 秒快速预检，不可用时 503
- **缓存预热修复**：JSON 反序列化兼容双格式
- **API 端口对齐**：前端代理端口修正为 52320
- 详见 [Bug知识库](docs/project/Bug知识库.md) Bug-029/030/031/032

---

**文档版本**：v4.8（事实对齐修订） | **最后更新**：2026-08-31 | **许可证**：MIT
