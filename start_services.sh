#!/bin/bash
# 转发到 scripts/start_services.sh（裸机非规范入口）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec bash "$ROOT/scripts/start_services.sh" "$@"
