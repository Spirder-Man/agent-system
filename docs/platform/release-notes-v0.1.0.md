# 苍卫 v0.1.0 — 首次公开源码包

公开作品名 **苍卫**（工程名 Agent1 / `agent-system`）。面向复杂高风险场景的可审计合规 Agent；当前验证场是化工园区危化品储存审查。

**法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。** LLM 不可用时，门卫 + 责任链 + 规则引擎仍给出可审计结论。

本发行是**源码包**，不含 GGUF 权重、不含 `docker save` 镜像、不含国家标准全文。平台自动挂上的「Source code zip / tar.gz」是整仓快照；下面三档是带 `START.md` 的启动包，解压后先读根目录 `START.md`。

## 下哪一档

| 档 | 附件 | 适合谁 | 解压后 |
|----|------|--------|--------|
| 容器化 | `cangwei-docker-v0.1.0.zip` / `.tar.gz` | 无 GPU、先验收甲醇×硝酸 | `docker compose -f docker-compose.demo.yml`，**不必下模型** |
| CPU | `cangwei-cpu-v0.1.0.zip` / `.tar.gz` | 无卡但要跑 llama.cpp | 放入 8B + embed 后 `docker-up cpu` |
| GPU | `cangwei-gpu-v0.1.0.zip` / `.tar.gz` | 有 NVIDIA | 放入模型后 `docker-up gpu`（首次编 CUDA 约 10–30 分钟） |

克隆仓库也可以，不必下压缩包：

- Gitee：https://gitee.com/liuchao_yue/agent-system
- GitHub：https://github.com/Spirder-Man/agent-system

## 能做什么

- 双通道：事实 = C# 工具；解释 = LLM。`RegulationRefs` 白名单之外的 GB 号会被删掉。
- 无 GPU 演示：储存禁忌走 `DeterministicRuleEngine`。
- 身份：JWT `admin` / `auditor` / `viewer`。演示账号 `admin` / `changeme`，仅本地。
- 审计：`audit_logs` 应用层 SHA256 哈希链。

## 边界（请先读）

- 仅作合规审查辅助，不替代持证安全管理人员。
- 仓库与压缩包都不含国家标准全文；甲醇×硝酸验收用 SQL 种子，不依赖国标 PDF。
- 未对接真实 ERP / WMS / EHS。
- 不是已定级备案或已测评的等保对象。
- **RTX 3070（2026-09-05/06）**：未过最小冒烟。
- **飞致云 RTX 4090 离线包（2026-09-07/08）**：`gpu-quick` 通过；`gpu-full` 因 L2 缓存未过，**本轮总判定未通过**。离线包能跑 ≠ 本仓 `Dockerfile.llama`（钉 llama.cpp b5512）已在 4090 重编发布。

演示视频（与本 tag 无关）仍在：https://gitee.com/liuchao_yue/agent-system/releases/tag/os2026-demo

文档入口：[README.md](../../README.md)、[docs/README.md](../README.md)。
