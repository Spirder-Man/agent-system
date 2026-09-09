# scripts

部署与测试 runbook，不是第二套应用运行时。

| 入口 | 做什么 |
|------|--------|
| `docker-up.ps1` / `docker-up.sh` | 起 GPU 或 CPU 栈 |
| `download-models.ps1` / `.sh` | 校验或按 URL 拉 GGUF |
| `gpu-five-layer.ps1` | 五层两档（quick ≠ full） |
| `demo-compatibility.ps1` / `.sh` | 无 GPU 储存兼容性自检 |
| `record-os2026-demo.ps1` | 大赛录片 |
| `pack-source-releases.ps1` / `.sh` | 打 CPU / GPU / 容器化源码 zip 与 tar.gz |
| `DEPLOY-EVAL.md` | 评测流水线说明 |

完整说明：[docs/infra/说明书.md](../docs/infra/说明书.md)
