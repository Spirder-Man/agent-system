#!/usr/bin/env bash
# 评委验收：甲醇 vs 硝酸 → 禁配 + GB 15603（不依赖 GPU）
# 请求体用 JSON \u 转义，避免 Windows Git Bash 把中文 curl -d 弄坏。
# 不强制 python：Windows Git Bash 经常没有解释器。
set -euo pipefail
API="${DEMO_API_URL:-http://localhost:5000}"
USER="${DEMO_USER:-admin}"
PASS="${DEMO_PASSWORD:-changeme}"
# 甲醇 / 硝酸
COMPAT_JSON='{"substanceA":"\u7532\u9187","substanceB":"\u785d\u9178"}'

extract_token() {
  local raw="$1"
  local t=""
  if command -v python3 >/dev/null 2>&1; then
    t=$(printf '%s' "$raw" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('token') or d.get('Token') or '')" 2>/dev/null || true)
  fi
  if [ -z "$t" ] && command -v python >/dev/null 2>&1; then
    t=$(printf '%s' "$raw" | python -c "import json,sys; d=json.load(sys.stdin); print(d.get('token') or d.get('Token') or '')" 2>/dev/null || true)
  fi
  if [ -z "$t" ] && command -v node >/dev/null 2>&1; then
    t=$(printf '%s' "$raw" | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{try{const o=JSON.parse(s);process.stdout.write(String(o.token||o.Token||''))}catch(e){}})" 2>/dev/null || true)
  fi
  if [ -z "$t" ]; then
    t=$(printf '%s' "$raw" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  fi
  printf '%s' "$t"
}

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

LOGIN=$(curl -sS -f -X POST "$API/api/Auth/login" \
  -H "Content-Type: application/json" \
  --data-binary "{\"username\":\"$USER\",\"password\":\"$PASS\"}")
TOKEN=$(extract_token "$LOGIN")
if [ -z "$TOKEN" ]; then
  echo "Login failed: $LOGIN"
  exit 1
fi

RESP=$(curl -sS -f -X POST "$API/api/Compliance/storage/compatibility" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary "$COMPAT_JSON")

echo "$RESP"
echo "$RESP" | grep -E -q 'GB 15603' || {
  echo "验收未看到 GB 15603，请检查 API 日志。"
  exit 1
}
echo "$RESP" | grep -E -q '禁止|严禁|不可|不能同库|禁配' || {
  echo "验收未看到禁配含义，请检查 API 日志。"
  exit 1
}
echo "PASS: 甲醇与硝酸储存禁忌（规则引擎，无 GPU）"
