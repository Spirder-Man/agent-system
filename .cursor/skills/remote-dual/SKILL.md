---
name: remote-dual
description: 双远程与本地/远程口径。Use when git remotes, origin, github, Gitee, GitHub, PR, push, CI Actions, 本地对不上远程, SSH tunnel, 15000, 15001, or staging.
---

# 本地与远程

## 远程名

- `origin` → Gitee `liuchao_yue/agent-system`
- `github` → GitHub `Spirder-Man/agent-system`

推送两边只在用户批准后（`review-commit-push`）。禁止 force push `master`，除非用户书面要求。

## MCP

必要 MCP **只有 GitHub**（用户级 `user-github`）：看 Issue / PR / Actions。**不要**把 token 写入仓库。认证失败则用 `gh`。Gitee 无 MCP，用 `git` / 网页。不要加 Playwright、Docker、Memory MCP。

## 不要进本仓

机房 SSH/SCP、`ssh-runner`、`gpu-five-layer.ps1`、飞致云编排。公开 clone 只走 README 三条路径。

## 隧道

本机 `15000`/`15001` 不是默认 API。联调远程时显式 `VITE_PROXY_TARGET` / `API_URL` / `health-check.ps1 -ApiUrl`。不要把隧道口写进 Vite 默认。
