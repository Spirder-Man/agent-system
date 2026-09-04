#!/bin/bash
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

echo "=== 1. 清理旧构建 ==="
pkill -9 -f "Agent1.Api" 2>/dev/null || true
sleep 2
cd "$PROJECT_DIR"

find . -path "*/bin/*/appsettings.json" -delete
find . -path "*/bin/*/appsettings.*.json" -delete

echo "=== 2. 重新构建 ==="
export LLM_ENDPOINT="${LLM_ENDPOINT:-http://localhost:8080/v1}"
export EMBEDDING_ENDPOINT="${EMBEDDING_ENDPOINT:-http://localhost:8081/v1}"
export DB_HOST="${DB_HOST:-localhost}"
export DB_NAME="${DB_NAME:-chemical_park_ai_agent}"
export ASPNETCORE_URLS="${ASPNETCORE_URLS:-http://0.0.0.0:5001}"
export DOTNET_USE_POLLING_FILE_WATCHER=true
export KNOWLEDGE_BASE_PATH="${KNOWLEDGE_BASE_PATH:-/root/autodl-tmp/knowledgebase}"

dotnet build Agent1.Api -c Release --no-restore 2>&1 | tail -3

echo "=== 3. 启动 API ==="
nohup dotnet run --project Agent1.Api -c Release --no-launch-profile --no-build \
  > /root/autodl-tmp/logs/api-e2e.log 2>&1 &
API_PID=$!
echo "API PID: $API_PID"
sleep 30

echo "=== 4. 健康检查 ==="
curl -s http://localhost:5001/health/live
echo ""

echo "=== 5. 登录测试 ==="
LOGIN=$(curl -s -X POST http://localhost:5001/api/Auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD:-changeme}\"}")
echo "Login: ${#LOGIN} chars"
TOKEN=$(echo "$LOGIN" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

echo "=== 6. Token 验证测试 ==="
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/api/eval/status/test123 \
  -H "Authorization: Bearer $TOKEN" --max-time 5)
echo "Protected endpoint: HTTP $CODE"
