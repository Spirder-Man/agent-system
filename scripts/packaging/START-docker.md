# 苍卫 · 容器化档（无 GPU）

这一包是源码，**不含** GGUF 权重。解压后用 Docker 即可验收甲醇 × 硝酸禁配：走确定性规则引擎，不起 llama.cpp。

演示账号仅本地：`admin` / `changeme`。口令请改进 `.env`，不要提交。

## 前提

- Docker Engine 或 Docker Desktop，Compose V2（`docker compose`）
- 不必有 NVIDIA GPU，不必下载模型

## 启动

在解压后的目录里：

```bash
cp .env.example .env
# 至少改 JWT_KEY（≥32 字符）、DB_PASSWORD

docker compose -f docker-compose.demo.yml up -d --build
curl http://localhost:5000/health/live

# 自检：登录后打储存兼容性接口，应见禁止同库与 GB 15603
bash scripts/demo-compatibility.sh
# Windows:
# powershell -ExecutionPolicy Bypass -File scripts/demo-compatibility.ps1
```

本档 compose **只起 PostgreSQL + API**，不起前端 Nginx。看页面：

```bash
cd agent1-web && npm install && npm run dev
```

浏览器：`http://localhost:5173`，登录后打开储存兼容性。

更完整的说明：根目录 [README.md](README.md)、[docs/infra/说明书.md](docs/infra/说明书.md)。

## 不要用本档做的事

- 不要跑 `docker-up gpu`（那是 GPU 档，首次会编 CUDA 镜像）
- 不要指望包内有 `models/*.gguf`
- 国标全文不在包内；甲醇 × 硝酸验收只用 SQL 种子
