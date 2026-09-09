## 改动

- 

## 是否碰到事实通道

法规号 / 储存禁忌 / 安全距离 / `RegulationRefs` / `DeterministicRuleEngine` / `OutputSanitizer`：

- [ ] 未改
- [ ] 改了，并补充了可复现测试或脚本验收

## 检查

- [ ] 未提交 `.env`、密钥、GGUF、国家标准全文
- [ ] 相关测试已跑（至少改动模块：`dotnet test Agent1.Tests --filter "Category!=Integration"` 或 `agent1-web` 的 `npx vitest run`）
- [ ] 文档口径未写超（gpu-full、等保、国标全文）
