#!/bin/bash
# ============================================================
# Agent1 裸机一键启动（非规范入口）
# 规范入口: scripts/docker-up 或 docker-compose.demo.yml
# 用法: 在项目根目录准备 .env 后执行  bash start_services.sh
# 启动顺序: PG → llama LLM → llama Embed → .NET API
# API 默认 :5000（与 compose / Program.cs 一致）
# 凭据只从 .env 读取，缺变量则退出
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
else
  echo "缺少 $SCRIPT_DIR/.env ，请先: cp .env.example .env 并填入本机口令"
  exit 1
fi

: "${DB_PASSWORD:?Set DB_PASSWORD in .env}"
: "${JWT_KEY:?Set JWT_KEY in .env}"
: "${AUTH_ACCOUNTS_JSON:?Set AUTH_ACCOUNTS_JSON in .env}"

export ASPNETCORE_URLS="${ASPNETCORE_URLS:-http://0.0.0.0:5000}"
export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Production}"
export DB_PASSWORD
export JWT_KEY
export AUTH_ACCOUNTS_JSON

# 远程机路径可用环境变量覆盖；以下为 AutoDL 类机器的示例，不含口令
PROJECT_DIR="${PROJECT_DIR:-$HOME/autodl-tmp/agent-system}"
LLAMA_BIN="${LLAMA_BIN:-$HOME/autodl-tmp/llama.cpp/build/bin/llama-server}"
MODEL_DIR="${MODEL_DIR:-$HOME/autodl-tmp/Models}"
LOG_DIR="${LOG_DIR:-$HOME/autodl-tmp/logs}"

mkdir -p "$LOG_DIR"
cd "$PROJECT_DIR"

echo "========================================"
echo "  Agent1 四服务启动"
echo "========================================"

# ── 1. PostgreSQL ──
echo "[1/4] PostgreSQL..."
if pg_isready -q 2>/dev/null; then
  echo "  已运行"
else
  pg_ctlcluster 16 main start 2>/dev/null && echo "  已启动" || {
    pg_ctl start -D /var/lib/postgresql/16/main -l /var/log/postgresql/postgresql.log 2>/dev/null && echo "  已启动" || echo "  启动失败"
  }
fi

# ── 2. llama.cpp LLM ──
echo "[2/4] llama.cpp LLM (8080)..."
pkill -f "llama-server.*8080" 2>/dev/null || true
sleep 1

if [ ! -f "$LLAMA_BIN" ]; then
  echo "  llama-server 未找到: $LLAMA_BIN"
  exit 1
fi

LLM_MODEL=$(ls "$MODEL_DIR"/[Qq]wen*gguf 2>/dev/null | head -1)
if [ -z "$LLM_MODEL" ]; then
  echo "  LLM 模型未找到 ($MODEL_DIR)"
  exit 1
fi

nohup "$LLAMA_BIN" -m "$LLM_MODEL" \
  --host 0.0.0.0 --port 8080 -c 32768 -ngl 99 --flash-attn on \
  > "$LOG_DIR/llama-server.log" 2>&1 &
echo "  已启动 (pid $!) → $(basename "$LLM_MODEL")"

# ── 3. llama.cpp Embedding ──
echo "[3/4] llama.cpp Embedding (8081)..."
pkill -f "llama-server.*8081" 2>/dev/null || true
sleep 1

EMBED_MODEL=$(ls "$MODEL_DIR"/{nomic,bge}*gguf 2>/dev/null | head -1)
if [ -z "$EMBED_MODEL" ]; then
  echo "  Embedding 模型未找到，跳过"
else
  nohup "$LLAMA_BIN" -m "$EMBED_MODEL" \
    --host 0.0.0.0 --port 8081 --embedding -c 8192 -ngl 99 -b 2048 -ub 2048 \
    > "$LOG_DIR/llama-embed.log" 2>&1 &
  echo "  已启动 (pid $!) → $(basename "$EMBED_MODEL")"
fi

# ── 4. 心跳轮询等 LLM 就绪 ──
echo "[4/4] 等待 LLM 模型加载..."
LOADED=false
for i in $(seq 1 20); do
  if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "  LLM 就绪 (${i}x3s)"
    LOADED=true
    break
  fi
  sleep 3
done
if [ "$LOADED" = false ]; then
  echo "  LLM 超时未就绪，查看日志: tail -5 $LOG_DIR/llama-server.log"
fi

# ── 5. .NET API ──
echo ""
echo "--- 启动 .NET API ---"
pkill -f "dotnet.*Agent1.Api" 2>/dev/null || true
sleep 2

dotnet build Agent1.Api/Agent1.Api.csproj -c Release --nologo -v q
nohup dotnet run --project Agent1.Api --configuration Release --no-launch-profile \
  > "$LOG_DIR/api-e2e.log" 2>&1 &

for i in $(seq 1 10); do
  if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "  API 就绪 (${i}x2s)"
    break
  fi
  sleep 2
done

# ── 最终验证 ──
echo ""
echo "========================================"
echo "  健康检查"
echo "========================================"

check() {
  local name=$1 url=$2
  printf "  %-20s " "$name"
  if curl -s --max-time 3 "$url" > /dev/null 2>&1; then
    echo "ok"
  else
    echo "fail"
  fi
}

check "LLM (8080)"        "http://localhost:8080/health"
check "Embed (8081)"      "http://localhost:8081/health"
check ".NET API (5000)"   "http://localhost:5000/health"

echo ""
curl -s http://localhost:5000/health | python3 -m json.tool 2>/dev/null || echo "API 未响应 → tail -20 $LOG_DIR/api-e2e.log"
