#!/bin/bash
export ASPNETCORE_URLS="${ASPNETCORE_URLS:-http://0.0.0.0:5001}"
export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Production}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

: "${DB_PASSWORD:?Set DB_PASSWORD in .env}"
: "${JWT_KEY:?Set JWT_KEY in .env}"
: "${AUTH_ACCOUNTS_JSON:?Set AUTH_ACCOUNTS_JSON in .env}"

cd "${PROJECT_DIR:-/root/autodl-tmp/agent-system}"
dotnet run --project Agent1.Api -c Release --no-launch-profile
