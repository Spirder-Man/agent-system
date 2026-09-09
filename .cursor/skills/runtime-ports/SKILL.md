---
name: runtime-ports
description: 启动、Docker、联调或端口占用时按端口登记选择可共存组合。Use when starting services, docker compose, docker-up, Vite, 端口冲突, 15000, 5000, 5173, 8088, or local vs container ports.
---

# 启动与端口

1. 打开 [docs/platform/运行时端口登记.md](../../../docs/platform/运行时端口登记.md)，**不要凭记忆填数字**。
2. 先问当前要哪条路径：有卡 `docker-up` / 无 GPU demo compose / 只 UI mock / 裸机 `scripts/start_services.sh`。
3. 互斥：全栈 compose 与 `docker-compose.demo.yml` **不能同开**（都要主机 API 5000）。裸机与 Docker 同理。
4. 默认 API 永远是主机 **5000**。隧道与 IDE launchSettings 口必须显式传参，禁止改成新默认。
5. 冲突只改 `.env` 已有变量。禁止新写一套 `start-xxx.sh` 换口。
6. Windows 看页面用 `WEB_PORT`（常 8088），Linux 默认 80。Real/Demo E2E 的 `PLAYWRIGHT_BASE_URL` 必须对上实际 Nginx，不要默认打 Vite `:5173`（Demo 档尤其）。
