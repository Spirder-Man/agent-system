# scripts

Clone 用户用的部署与验收入口。机房 SSH/SCP、远程重启、拉日志等内部工具不在本仓。阶段总闸：[docs/platform/工程治理.md](../docs/platform/工程治理.md)。API 默认 **http://localhost:5000**。端口互斥：[docs/platform/运行时端口登记.md](../docs/platform/运行时端口登记.md)。

**不要在本目录根层新写一次性脚本。** Agent 临时脚本只进 [`_scratch/`](_scratch/)（不入库）。历史 AutoDL / 任务编号脚本在 [`_legacy/`](_legacy/)（**不是入口**）。晋升进规范入口须改本 README 并经维护者同意。

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

评测相关（非日常起栈，但是仓库内正式脚本）：`run_eval_pipeline.ps1`、`validate-eval-schema.py`、`push-eval-metrics.sh`、`diag-llama-libs.ps1`、`record-os2026-demo.ps1`、`packaging/`。

## 裸机辅助（非规范；默认口已与 5000 对齐）

无 Docker 时才用。`API_URL` / `ASPNETCORE_URLS` 可覆盖。SSH 隧道请显式设 `API_URL=http://localhost:15001`。

| 脚本 | 做什么 |
|------|--------|
| `start_services.sh`（仓库根同名文件只转发到这里） | 裸机起 llama + API；读仓库根 `.env` |
| `start-api.sh` | 只起 API（假定 PG + llama 已在） |
| `test_rule_engine.sh`、`test_double_gate.sh`、`quick_test.sh` | 打本机 API 的检查 |

健康检查（前端仓）：`agent1-web/scripts/health-check.ps1`，默认 `:5000`；隧道 `-ApiUrl http://localhost:15001`。

完整说明：[docs/infra/说明书.md](../docs/infra/说明书.md)
