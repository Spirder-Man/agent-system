# scripts

Clone 用户用的部署与验收入口。机房 SSH/SCP、远程重启、拉日志等内部工具不在本仓。阶段总闸：[docs/platform/工程治理.md](../docs/platform/工程治理.md)。API 默认 **http://localhost:5000**。

## 规范入口（只用这些）

| 入口 | 做什么 |
|------|--------|
| `docker-up.ps1` / `.sh` | 起 GPU 或 CPU 栈 |
| `download-models.ps1` / `.sh` | 校验或按 URL 拉 GGUF |
| `demo-compatibility.ps1` / `.sh` | 无 GPU 储存兼容性自检（默认 `:5000`） |
| `pack-source-releases.ps1` / `.sh` | 打 CPU / GPU / 容器化源码 zip 与 tar.gz |
| `llama-entrypoint.sh` | llama 镜像入口 |
| `check-coverage.ps1` | 本地覆盖率 |
| `DEPLOY-EVAL.md` | 评测流水线说明 |

## 裸机辅助（非规范；默认口已与 5000 对齐）

无 Docker 时才用。`API_URL` / `ASPNETCORE_URLS` 可覆盖。SSH 隧道请显式设 `API_URL=http://localhost:15001`。

| 脚本 | 做什么 |
|------|--------|
| `start_services.sh`、仓库根 `start_services.sh` | 裸机起 llama + API |
| `test_rule_engine.sh`、`test_double_gate.sh`、`quick_test.sh`、`test_jwt.sh` | 打本机 API 的一次性检查 |
| `check_env.sh`、`fix_db.sh` | 排障；`fix_db.sh` 含机房路径，勿当通用安装器 |

健康检查（前端仓）：`agent1-web/scripts/health-check.ps1`，默认 `:5000`；隧道 `-ApiUrl http://localhost:15001`。

完整说明：[docs/infra/说明书.md](../docs/infra/说明书.md)
