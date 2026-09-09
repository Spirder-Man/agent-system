# Agent1

核心库：双通道合规（事实=C# / 解释=LLM）、RAG、规则引擎、编排、审计链。

不是 HTTP 服务。宿主是 [`Agent1.Api`](../Agent1.Api/README.md) 或本目录 CLI。

```bash
dotnet run --project Agent1.Api
dotnet test Agent1.Tests --filter "Category!=Integration"
dotnet run --project Agent1          # CLI 菜单
```

完整说明：[docs/Agent1/说明书.md](../docs/Agent1/说明书.md)
