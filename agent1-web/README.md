# agent1-web

苍卫 / Agent1 的 Vue 3 前端。契约在 `src/types/api.ts`，与后端 DTO 手工对齐。

```bash
npm install
npm run dev:mock    # 只看 UI，MSW，不需要后端
npm run dev         # 代理到真实 API
npm test            # Vitest
```

生产构建由仓库根 Docker `web` 服务提供 Nginx。E2E 三档见 [docs/e2e/说明书.md](../docs/e2e/说明书.md)。

完整说明：[docs/agent1-web/说明书.md](../docs/agent1-web/说明书.md)  
Mock 层架构：[src/mocks/README.md](src/mocks/README.md)
