# 苍卫 · CPU 档

这一包是源码，**不含** GGUF。用 Docker 在 CPU 上跑 llama.cpp（`-ngl 0`），不需要 NVIDIA 卡。须自行放入 8B + embed 两件权重（约 5GB）。

演示账号仅本地：`admin` / `changeme`。

## 前提

- Docker Compose V2；内存建议 ≥ 16 GB；磁盘建议 ≥ 30 GB
- 不需要 GPU
- 模型文件名必须与 [models/README.md](models/README.md) 完全一致

需要的文件：

| 文件 | 用途 |
|------|------|
| `Qwen_Qwen3-8B-Q4_K_M.gguf` | LLM :8080 |
| `nomic-embed-text-v1.5.f16.gguf` | 向量 :8081 |

## 启动

```bash
cp .env.example .env
# 编辑 JWT_KEY、DB_PASSWORD；Windows 无管理员权限时 WEB_PORT=8088

# 校验 models/ 是否已有上述文件；设置 AGENT1_MODEL_BASE_URL 才会下载
bash scripts/download-models.sh
# Windows: powershell -ExecutionPolicy Bypass -File scripts/download-models.ps1

bash scripts/docker-up.sh cpu
# Windows: powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 cpu

curl http://localhost:5000/health/live
```

浏览器打开 `http://localhost`（或 `.env` 的 `WEB_PORT`）。储存兼容性查询甲醇与硝酸，应禁止同库并给出 GB 15603。

无模型、只想先看规则引擎时，改用容器化档的 `docker-compose.demo.yml`。

完整说明：[README.md](README.md)、[docs/infra/说明书.md](docs/infra/说明书.md)、[docs/infra/deploy/Docker容器化一键部署.md](docs/infra/deploy/Docker容器化一键部署.md)。
