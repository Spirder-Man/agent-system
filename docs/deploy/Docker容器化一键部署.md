# Docker 容器化一键部署

在仓库根目录 `agent-system/` 操作。当前默认仍是本机构建镜像（`docker-compose.yml` 含 `build:`）。  
GPU 冒烟通过并 push 镜像之后，才改用 [docker-compose.release.yml.example](../../docker-compose.release.yml.example) 做 `compose pull`。**现在不要** `-f` 那份 example 去拉远程仓库。  
**2026-09-05/06 RTX 3070 实测未通过冒烟**（vision 拒 `--mmproj`），见 [实测记录](../testing/2026-09-06_RTX3070容器实测记录.md)。

完整前提条件（硬件 / 驱动 / 端口）见 [开源项目分发落地方案](./开源项目分发落地方案.md) §0。GGUF 文件名与自检脚本见 [models/README.md](../../models/README.md)。

演示账号仅本地：`admin` / `changeme`。生产口令只写本机 `.env`。

---

## 准备工作

```powershell
# 进入本仓库根目录（不要用过时盘符）
cd <本机>/agent-system

docker version
docker compose version

# 没有 .env 时：
copy .env.example .env
# Linux: cp .env.example .env
```

编辑 `.env`：至少填写 `DB_PASSWORD`、`JWT_KEY`（不少于 32 字符）。Windows 无管理员权限时设 `WEB_PORT=8088`。

准备 GGUF（8B + embed 必填；VL + mmproj 仅 GPU 视觉需要）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/download-models.ps1
# Linux: bash scripts/download-models.sh
```

未设置 `AGENT1_MODEL_BASE_URL` 时，脚本只校验本地文件并打印拷贝说明，不会从网上下载。

---

## 推荐：一键脚本

与 [scripts/docker-up.ps1](../../scripts/docker-up.ps1) / [scripts/docker-up.sh](../../scripts/docker-up.sh) 对齐。

```powershell
# GPU（默认 compose）。显存 ≥20GB 时脚本自动起 llama-vision :8083；
# 8GB 卡自动跳过视觉。`.env` 写 ENABLE_VISION_OCR=true|false 可强制覆盖。
powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 gpu

# 无 GPU、但仍要 llama.cpp CPU 推理（叠 docker-compose.cpu.yml）
powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 cpu
```

```bash
bash scripts/docker-up.sh gpu
bash scripts/docker-up.sh cpu
```

无 GPU、也不要 llama 时，用演示栈（路径 2）：

```bash
docker compose -f docker-compose.demo.yml up -d --build
```

---

## 等价的手动步骤（GPU）

### 1. 拉取基础镜像（Postgres）

```powershell
docker compose pull postgres
```

观测栈（Prometheus / Grafana）**不是**默认六容器的一部分。需要时再叠 overlay：

```powershell
docker compose -f docker-compose.yml -f docker-compose.obs.yml pull prometheus grafana
```

### 2. 构建 llama.cpp CUDA 镜像（首次约 10–30 分钟）

```powershell
docker compose build llama-server llama-embed llama-vision
```

三个服务共用本地 tag `agent1-llama-cuda:latest`。**本机工作区** `Dockerfile.llama` 克隆 llama.cpp **b5512** 并 CUDA 编译（构建目标：`--mmproj` + tools+stream）。这不是 2026-09-05/06 RTX 3070 实测结论，也还不是 4090 冒烟结论。无 NVIDIA 卡的机器也可以**编**镜像，但不要用 GPU compose **跑**（`deploy.devices` 需要 GPU）。生产 4090 **只用** `docker-up`：显存 ≥20GB 时点名起 `llama-vision`。裸 `compose up -d` **不**启 vision（`profiles: [vision]`）。

### 3. 构建 API 与 Web

```powershell
docker compose build api web
```

### 4. 启动

日常 / 生产请用上一节的 `docker-up`（4090 会自动起 vision）。裸启动：

```powershell
docker compose up -d
```

服务：postgres、llama-server :8080、llama-embed :8081、api :5000、web（`.env` 的 `WEB_PORT`，默认 `80`）。`llama-vision` 在 `profiles: [vision]` 下，**裸 `up -d` 不会拉起 8083**。24GB+ 要视觉：`docker-up`，或 `docker compose --profile vision up -d`，或点名 `llama-vision`。

### 5. 验证

```powershell
docker compose ps
curl http://localhost:5000/health/live
```

浏览器：`http://localhost` 或 `http://localhost:8088`。Swagger：`http://localhost:5000/swagger`。

观测栈（可选）：

```powershell
docker compose -f docker-compose.yml -f docker-compose.obs.yml up -d
# Prometheus :9090  Grafana :3000（账号见 .env 的 GRAFANA_*）
```

---

## 常用命令

```powershell
docker compose logs -f api
docker compose logs -f llama-server
docker compose restart api
docker compose down          # 停止，保留数据卷
docker compose down -v       # 停止并删除 postgres 数据
```

---

## 附录：本机构建 llama 时注意

| 问题 | 说明 |
|---|---|
| 首次很慢 | CUDA 编译 10–30 分钟，属正常 |
| 模型文件名 | 必须是 `Qwen_Qwen3-8B-Q4_K_M.gguf` 与 `nomic-embed-text-v1.5.f16.gguf`（不要用旧文档里的 `qwen3-8b-q4_k_m.gguf` / `Q8_0`） |
| 缺模型 | llama 不健康；可先 `docker compose up -d postgres api web` 做无 LLM 检查，或改走 `docker-compose.demo.yml` |
| `libllama.so` / exit 127 | 运行镜像必须带共享库。`4e5b6e8` 已收集 `.so`；3070 第一波仍是缺库旧 tar，第二波已能加载。**旧**离线 `agent1-llama-cuda.tar` 在换包前仍缺库，见落地方案 §8.0 |
| `--mmproj` 拒参 | 3070 第二波 vision ×43。工作区现钉 **b5512**，须在 **4090** 上冒烟；未 Up / 未过冒烟前不要写「已修」 |
| 阶段 B | GPU 最小冒烟通过后，再 push 钉版本镜像，改用 release overlay 做 `compose pull`，用户不必本机编 CUDA |

---

## Windows

| 项 | 说明 |
|---|---|
| Docker Desktop | WSL2 后端；GPU 路径需在设置里开启 GPU |
| 端口 80 | 无管理员权限时 `.env` 设 `WEB_PORT=8088` |
| 无卡却跑默认 compose | `deploy.devices` 会失败；改用路径 2（demo 或 `docker-up.ps1 cpu`） |
