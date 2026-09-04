#!/usr/bin/env bash
# 评委验收：甲醇 vs 硝酸 → 禁配 + GB 15603（不依赖 GPU）
set -euo pipefail
API="${DEMO_API_URL:-http://localhost:5000}"
USER="${DEMO_USER:-admin}"
PASS="${DEMO_PASSWORD:-changeme}"

echo "Waiting for $API/health/live ..."
for i in $(seq 1 40); do
  if curl -sf "$API/health/live" >/dev/null 2>&1; then
    echo "API live"
    break
  fi
  if [ "$i" -eq 40 ]; then
    echo "API did not become live. Try: docker compose -f docker-compose.demo.yml logs api"
    exit 1
  fi
  sleep 3
done

LOGIN=$(curl -sf -X POST "$API/api/Auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}")
TOKEN=$(printf '%s' "$LOGIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('token') or d.get('Token') or '')" 2>/dev/null \
  || printf '%s' "$LOGIN" | python -c "import json,sys; d=json.load(sys.stdin); print(d.get('token') or d.get('Token') or '')")
if [ -z "$TOKEN" ]; then
  echo "Login failed: $LOGIN"
  exit 1
fi

RESP=$(curl -sf -X POST "$API/api/Compliance/storage/compatibility" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"substanceA":"甲醇","substanceB":"硝酸"}')

echo "$RESP"
echo "$RESP" | grep -E -q 'GB 15603|禁止|严禁|不可|不能同库|禁配' || {
  echo "验收未看到禁配或 GB 15603 字样，请检查 API 日志。"
  exit 1
}
echo "PASS: 甲醇与硝酸储存禁忌（规则引擎，无 GPU）"
