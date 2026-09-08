# 远程评测六维度深度分析报告（飞致云 Docker）

> **自动生成** | 维度框架: D1-D6 | 方法: [系统日志解读与排障实战指南.md](../../docs/testing/系统日志解读与排障实战指南.md) / [系统日志阅读与分析实战教学.md](../../docs/testing/系统日志阅读与分析实战教学.md)
>
> 日志源已从 AutoDL `/root/autodl-tmp/logs` 改为 `ssh` + `docker compose logs`（gpu-eval-analyze.ps1）。不调用 download-analysis.ps1。

---

## 元数据

| 字段 | 值 |
|------|-----|
| 分析 ID | __ANALYSIS_ID__ |
| 评测模型 | __MODEL__ |
| 评测时间 | __EVAL_TS__ |
| 报告目录 | __OUT_DIR__ |
| 日志说明 | __LOG_NOTE__ |
| 容器全文报告 | __FULL_REPORT__ |

---

## D1 — 格式解析：评测数据概览

> **核心问题**：这次评测输出了什么？

### 总体指标

| 指标 | 值 | 说明 |
|------|-----|------|
| 评测用例数 | __TOTAL__ | 化工合规评测集（总纲 63 条） |
| 工具触发率 | __TOOL_RATE__ | 对照历史 85.7% |
| 参数准确率 | __PARAM_ACC__ | 对照历史 82.5% |
| 结论准确率 | __CONCLUSION_ACC__ | 对照历史 65.1%；理想 90% 从未达到，不作死门槛 |
| P@5 | __P5__ | 对照历史 50.5%；理想 Top-5≥85% 从未达到 |
| R@5 | __R5__ | RAG |
| P@10 | __P10__ | 对照历史 35.9% |
| R@10 | __R10__ | RAG |
| MRR | __MRR__ | 对照历史 0.584 |
| 忠实度 | __FAITH__ | 对照历史约 23.9% |
| 异常用例 | __ERR_CASES__ | cases 含 error |

### 工具调用分布

```
__TOOL_DIST__
```

### 数据来源说明

| 日志文件 | 行数 | 用途 |
|----------|------|------|
| eval.json | — | GET /api/Eval/status 的 report |
| api-eval-window.log | __API_LINES__ | docker compose logs api |
| llama-llm-tail.log | 切片 | llama-server |
| llama-embed-tail.log | 切片 | llama-embed |

---

## D2 — 业务映射：失败模式分类

> **核心问题**：哪些业务场景出错了？对应哪段代码？

### 失败用例分类

__FAIL_A__
__FAIL_B__
__FAIL_C__
__FAIL_D__

### 失败 → 代码映射表

| 失败模式 | 对应代码模块 | 排查入口 |
|----------|-------------|---------|
| A-未触发工具 | IntentRouter.cs / SK Auto FC | 关键词表 + FunctionCalling 配置 |
| B-参数错误 | FactExtractor.cs / FactAssembler.cs | 事实提取 → 参数组装链路 |
| C-结论错误 | EvalEngine.CheckConclusion() / ReflectionVerifier.cs | GB编号校验 + 结论比对逻辑 |
| D-其他 | AgentDialog.cs / Pipeline 入口 | TraceId 全链路追踪 |

---

## D3 — 数据链路：评测流水线追踪

> **核心问题**：数据从哪来、经过哪些步骤、到哪去？

### 评测执行链路

```
用户请求 (HTTP POST /api/Eval/run)
  |
  |- [1] AuthController.Login -> JWT Token
  |- [2] EvalController.RunEval -> EvalEngine.RunComplianceEvalAsync()
  |         |- 遍历 ComplianceEvalCase
  |         |- 每条: AgentDialog.ExecuteAsync()
  |         |   |- IntentRouter
  |         |   |- SK Auto Function Calling
  |         |   |- RAG (BM25 + Vector + RRF)
  |         |   +- LLM llama.cpp :8080
  |         +- ReflectionVerifier
  |
  +- [3] eval.json -> eval_reports/<stamp>/
```

### API 日志信号

| 信号 | 数量 | 含义 |
|------|------|------|
| Pipeline 日志行 | __PIPELINE_LINES__ | 评测期间处理的请求数 |
| FC 违约 (工具调用=0) | __FC_VIOLATIONS__ | LLM 绕过 Function Calling 直接输出 |
| 错误日志 (ERR/FATAL) | __API_ERRORS__ | 系统级异常 |
| 警告日志 (WRN) | __API_WARNS__ | 降级/非致命异常 |

---

## D4 — 设计意图：架构观察

> **核心问题**：为什么当前架构会出现这些结果？设计决策的边界在哪里？

### 当前架构约束

| 约束 | 影响 | 评测体现 |
|------|------|---------|
| Qwen3-8B Q4_K_M 量化 | 推理能力上限 | 结论准确率 baseline |
| IntentRouter 基于关键词 | 召回率 vs 精确率权衡 | A 类失败（未触发工具） |
| FC=Required 但 LLM 不完美遵循 | 工具调用率 < 100% | A 类失败 |
| ReflectionVerifier GB 校验 | 幻觉拦截 | 忠实度 / 幻觉声明 |
| RAG BM25+Vector+RRF 混合检索 | 知识召回质量 | P@K / 结论准确率 |

### 架构演进建议

- [ ] 工具触发率优化：如果 A 类失败 > 5 例，检查 IntentRouter 关键词覆盖率 + FC Prompt
- [ ] 结论准确率优化：如果 C 类失败 > 3 例，检查 RAG 召回质量 + Reflection
- [ ] 性能基线：如果单例耗时 > 30s，检查 Prompt 长度 + 模型并发配置

本轮不改 EvalEngine / 评测集。P2 结论准确率代码耦合见 docs/testing/P2-结论准确率提升-代码耦合分析.md。

---

## D5 — 异常识别：风险信号检测

> **核心问题**：有没有不对劲的？哪些需要立即处理？

### 异常等级分类

| 等级 | 信号 | 当前状态 | 响应 |
|:---:|------|:---:|------|
| **P0** | API 日志 ERR/FATAL | __P0__ | 立即修复 |
| **P1** | 结论准确率骤降 > 5%（相对 latest） | __P1CONC__ | 本次周期内修复 |
| **P1** | 工具调用率 < 80% | __P1TOOL__ | 排查 FC 链路 |
| **P2** | FC 违约次数异常 | __P2FC__ | 记录，下周期修复 |
| **P3** | 非致命警告 | __P3WRN__ | 无需处理 |

### 告警摘要

__ALERT_MD__

> 告警不把 gpu-full 整轮 exit 1。exit 1 只看 Gate1 / L2 / L3 / Eval 是否 completed。

---

## D6 — 性能分析：耗时与瓶颈

> **核心问题**：快不快？瓶颈在哪？

### 硬件基线（本轮飞致云）

| 组件 | 配置 |
|------|------|
| GPU | NVIDIA RTX 4090（按量实例） |
| 推理引擎 | llama.cpp (CUDA, docker 离线包) |
| 模型 | Qwen3-8B Q4_K_M |
| Embedding | nomic-embed-text-v1.5 |

### 评测耗时分析

- 总用例数: __TOTAL__
- 有实际工具名的用例: __TOOL_OK__
- 无实际工具名: __NO_TOOL__
- 预估单例 LLM 耗时: 秒级（亚秒 = 快路径，不是 GPU 证据）

### 优化建议

- [ ] 如果 Pipeline 耗时 > 30s/例，检查 Prompt 长度是否冗余
- [ ] 如果 Embedding 耗时异常，检查 llama-embed 显存配置
- [ ] 建立耗时趋势基线（需 >= 3 次评测数据）

---

## 附录 A：失败用例详情

__FAIL_APPENDIX__

---

## 附录 B：日志切片路径对照

| 日志 | 本地路径 |
|------|---------|
| 分析报告 | __ANALYSIS_PATH__ |
| 评测摘要 | __EVAL_JSON__ |
| 指标对照 | __COMPARISON_PATH__ |
| compose 合并 | __COMBINED_LOG__ |
| API 切片 | __API_LOG__ |
| llama LLM | __LLM_LOG__ |
| llama Embed | __EMBED_LOG__ |

> [测试总纲.md](../../docs/testing/测试总纲.md) §4.2
> [GPU全量校验手册.md](../../docs/testing/GPU全量校验手册.md)
