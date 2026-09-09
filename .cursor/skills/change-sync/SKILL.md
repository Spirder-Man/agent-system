---
name: change-sync
description: 改代码、契约、文档或页面时对照同批更新清单。Use when editing Agent1, Agent1.Api, agent1-web, docs, API contracts, 血谱, 说明书, or when the user mentions 文档对不上 or 口径.
---

# 同批更新

先读 [AGENTS.md](../../../AGENTS.md)。第一阶段默认 **不改** 冻结目录；只改文档/台账时仍走本清单。

对照并只更新实际碰到的项：

- 血管 / 数据源 / 降级 → [系统血谱.md](../../../docs/platform/系统血谱.md)
- HTTP 契约 → `agent1-web/src/types/api.ts`、MSW、模块说明书（`src` 冻结时只改说明书口径或登记债）
- 页面完成度 / 路由 → [页面完成度清单.md](../../../docs/platform/页面完成度清单.md)
- 默认口 → [运行时端口登记.md](../../../docs/platform/运行时端口登记.md)
- 测试命令 / CI 范围 → [测试台账.md](../../../docs/platform/测试台账.md)「最近变更」
- 仓库可见 → [CHANGELOG.md](../../../docs/platform/CHANGELOG.md)
- 过程 → [开发会话纪要](../../../docs/platform/开发会话纪要/README.md)

不要重写测试总纲千行正文。不要把 `docs/platform/skills/` 写成已接线 CI。
