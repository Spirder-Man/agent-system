# 苍卫 · GPU 档

这一包是源码，**不含** GGUF。用 Docker 在 NVIDIA GPU 上跑完整栈。首次会构建 CUDA llama 镜像，约 10–30 分钟。

演示账号仅本地：`admin` / `changeme`。

**不要把本档写成 gpu-full 已通过。** 飞致云 4090：`gpu-quick` 通过；`gpu-full` 因 L2 缓存未过。RTX 3070 实测未过冒烟。见发行说明。

## 前提

- NVIDIA 驱动；`nvidia-smi` 能列出 GPU
- Linux：NVIDIA Container Toolkit；Windows：Docker Desktop WSL2 且启用 GPU
- 内存建议 ≥ 16 GB；8B + 视觉同卡建议 **24 GB** 显存
- 模型见 [models/README.md](models/README.md)

至少需要：

| 文件 | 用途 |
|------|------|
| `Qwen_Qwen3-8B-Q4_K_M.gguf` | LLM :8080 |
| `nomic-embed-text-v1.5.f16.gguf` | 向量 :8081 |

视觉 / OCR 另需 `Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf` 与 `mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf`。显存不足时不要强行开 vision。

## 启动

```bash
cp .env.example .env
# 编辑 JWT_KEY、DB_PASSWORD；Windows 无管理员权限时 WEB_PORT=8088

bash scripts/download-models.sh
# Windows: powershell -ExecutionPolicy Bypass -File scripts/download-models.ps1

bash scripts/docker-up.sh gpu
# Windows: powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 gpu

curl http://localhost:5000/health/live
```

浏览器打开 `http://localhost`（或 `WEB_PORT`）。储存兼容性：甲醇 × 硝酸应禁止同库，出处 GB 15603。

没有卡时请改用 **CPU 档** 或 **容器化档**，不要对这份包跑 `docker-up gpu`。

完整说明：[README.md](README.md)、[docs/infra/说明书.md](docs/infra/说明书.md)、[docs/infra/deploy/Docker容器化一键部署.md](docs/infra/deploy/Docker容器化一键部署.md)。
