# GGUF 模型（不进 Git）

权重文件放在本目录（或 `.env` 的 `MODELS_PATH`），由 llama 容器只读挂载为 `/models`。  
本仓库 MIT **不覆盖** 这些权重；许可以各模型卡为准，见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。

校验（不下载）：

```bash
bash scripts/download-models.sh
# Windows: powershell -ExecutionPolicy Bypass -File scripts/download-models.ps1
```

设置 `AGENT1_MODEL_BASE_URL` 时，脚本才按文件名从该 URL 下载。未设置则只检查本地文件并打印检索关键词。

## 文件清单

| 文件 | 端口 / 用途 | 约大小 | 缺了会怎样 |
|---|---|---|---|
| `Qwen_Qwen3-8B-Q4_K_M.gguf` | 8080 LLM | ~4.8 GB | llama-server 不健康 |
| `nomic-embed-text-v1.5.f16.gguf` | 8081 向量 | ~0.3 GB | 入库无向量，仅 BM25 |
| `Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf` | 8083 视觉 | ~5.7 GB | OCR / 识图不可用；8080 仍可 |
| `mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf` | 8083 mmproj | ~1.3 GB | 同上 |

8B + embed 为完整对话 / RAG 所必需。VL 两件仅 GPU 视觉需要。

2026-09-05/06 RTX 3070 实测：8B 与 embed 已加载；vision 因 `--mmproj` 拒参从未加载 VL。缺 VL 文件不是那次 8083 失败的主因。详见 [3070 实测记录](../docs/infra/2026-09-06_RTX3070容器实测记录.md)。模块边界见 [docs/models/说明书.md](../docs/models/说明书.md)。

`SHA256SUMS` 里哈希暂为 `SKIP`：脚本只检查文件存在与最小体积。填入真实 SHA256 后才会做校验。

## 检索关键词（自行下载）

国内可先搜 ModelScope，国外用 Hugging Face。文件名必须与上表**完全一致**（compose 写死了路径）。

| 文件 | 建议检索 |
|---|---|
| Qwen3 8B Q4_K_M | ModelScope / HF：`Qwen3-8B` `Q4_K_M` `gguf` |
| nomic-embed f16 | `nomic-embed-text-v1.5` `f16` `gguf` |
| Qwen2.5-VL 7B Q4_K_M | `Qwen2.5-VL-7B-Instruct` `Q4_K_M` `gguf` |
| mmproj f16 | `mmproj` `Qwen2.5-VL-7B` `f16` `gguf` |

下载后改名为上表文件名，放到 `MODELS_PATH`。不要把 `.gguf` 提交进本仓库。
