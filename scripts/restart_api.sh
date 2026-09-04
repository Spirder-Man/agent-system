#!/bin/bash
# 从项目根 .env 加载凭据；缺变量则退出
set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:-/root/autodl-tmp/agent-system}"
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
fi
: "${DB_PASSWORD:?Set DB_PASSWORD in .env}"
: "${JWT_KEY:?Set JWT_KEY in .env}"
: "${AUTH_ACCOUNTS_JSON:?Set AUTH_ACCOUNTS_JSON in .env}"

pkill -9 -f "Agent1.Api" 2>/dev/null || true
sleep 2
cd "$PROJECT_DIR"

export LLM_ENDPOINT="${LLM_ENDPOINT:-http://localhost:8080/v1}"
export EMBEDDING_ENDPOINT="${EMBEDDING_ENDPOINT:-http://localhost:8081/v1}"
export DB_HOST="${DB_HOST:-localhost}"
export DB_NAME="${DB_NAME:-chemical_park_ai_agent}"
export ASPNETCORE_URLS="${ASPNETCORE_URLS:-http://0.0.0.0:5001}"
export DOTNET_USE_POLLING_FILE_WATCHER=true
export KNOWLEDGE_BASE_PATH="${KNOWLEDGE_BASE_PATH:-/root/autodl-tmp/knowledgebase}"

nohup dotnet run --project Agent1.Api -c Release --no-launch-profile \
  > /root/autodl-tmp/logs/api-e2e.log 2>&1 &

echo "API PID: $!"
sleep 25
echo -n "Health: "
curl -s --max-time 10 http://localhost:5001/health/live
echo ""
echo -n "Login: "
curl -s -X POST http://localhost:5001/api/Auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD:-changeme}\"}" --max-time 5
echo ""
