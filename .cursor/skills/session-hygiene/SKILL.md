---
name: session-hygiene
description: 收工清理临时脚本并追加开发会话纪要。Use when finishing a task, ending a session, claiming done, or after creating helper scripts, .ps1, .sh, or files under scripts/_scratch.
---

# 收工

声称完成前做完：

1. 列出 `scripts/_scratch/`。有文件则 **删除**，或写晋升提案（改 `scripts/README.md` 规范表，等用户同意后再移动）。
2. 确认仓库根、`docs/`、桌面没有新的一次性 `.ps1`/`.sh`。
3. 复制 [docs/platform/开发会话纪要/_template.md](../../../docs/platform/开发会话纪要/_template.md) 为 `YYYY-MM-DD_短标题.md`（或追加当天文件）。填写：做了什么、脚本去向、踩坑、台账勾选。
4. 克隆用户能感知的变更才追加 [CHANGELOG.md](../../../docs/platform/CHANGELOG.md)。
5. 不要提交 `_scratch`、`.env`、coverage、GGUF。

提交仍走 `review-commit-push`，等 **通过**。
