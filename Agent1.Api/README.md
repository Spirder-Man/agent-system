# Agent1.Api

ASP.NET Core 8 HTTP API。鉴权、限流、把请求交给 `Agent1` 核心库。

```bash
dotnet run --project Agent1.Api
curl http://localhost:5000/health/live
```

默认端口 5000。必填环境变量见仓库 [`.env.example`](../.env.example)。

完整说明（路由表、中间件、如何加接口）：[docs/Agent1.Api/说明书.md](../docs/Agent1.Api/说明书.md)
