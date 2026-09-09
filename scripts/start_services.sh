#!/bin/bash
# 裸机启动（非规范）。规范入口: docker-up / docker-compose.demo.yml。API 默认 :5000。
set -e

MODEL_DIR=/root/autodl-tmp/models
LLAMA_SERVER=/root/autodl-tmp/llama.cpp/build/bin/llama-server
PROJECT_DIR=/root/autodl-tmp/agent-system
LOG_DIR=/root/autodl-tmp/logs

mkdir -p $LOG_DIR

# 清理旧进程
pkill -9 -f llama-server 2>/dev/null || true
pkill -9 -f "Agent1.Api" 2>/dev/null || true
sleep 2

# ===== 1. LLM 服务 (Qwen3-8B, 端口 8080) =====
echo "[1/3] 启动 LLM 服务 (Qwen3-8B, 端口 8080)..."
CUDA_VISIBLE_DEVICES=0 nohup $LLAMA_SERVER \
    -m $MODEL_DIR/Qwen_Qwen3-8B-Q4_K_M.gguf \
    --host 0.0.0.0 --port 8080 \
    -ngl 99 -c 4096 \
    > $LOG_DIR/llm-server.log 2>&1 &
LLM_PID=$!
echo "  PID: $LLM_PID"

# ===== 2. Embedding 服务 (nomic-embed, 端口 8081) =====
echo "[2/3] 启动 Embedding 服务 (nomic-embed, 端口 8081)..."
CUDA_VISIBLE_DEVICES=0 nohup $LLAMA_SERVER \
    -m $MODEL_DIR/nomic-embed-text-v1.5.f16.gguf \
    --host 0.0.0.0 --port 8081 \
    -ngl 99 --embeddings \
    > $LOG_DIR/embed-server.log 2>&1 &
EMBED_PID=$!
echo "  PID: $EMBED_PID"

# 等待模型加载
echo "  等待模型加载..."
sleep 30

# ===== 3. .NET API (端口 5000，与 compose 一致) =====
echo "[3/3] 启动 .NET API (端口 5000)..."

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

export LLM_ENDPOINT="${LLM_ENDPOINT:-http://localhost:8080/v1}"
export EMBEDDING_ENDPOINT="${EMBEDDING_ENDPOINT:-http://localhost:8081/v1}"
export DB_HOST="${DB_HOST:-localhost}"
export DB_NAME="${DB_NAME:-chemical_park_ai_agent}"
export ASPNETCORE_URLS="${ASPNETCORE_URLS:-http://0.0.0.0:5000}"
export DOTNET_USE_POLLING_FILE_WATCHER=true
export KNOWLEDGE_BASE_PATH="${KNOWLEDGE_BASE_PATH:-/root/autodl-tmp/knowledgebase}"

cd $PROJECT_DIR
nohup dotnet run --project Agent1.Api -c Release --no-launch-profile \
    > $LOG_DIR/api-e2e.log 2>&1 &
API_PID=$!
echo "  PID: $API_PID"

# ===== 健康检查 =====
echo ""
echo "===== 健康检查 ====="
sleep 10

echo -n "LLM (8080): "
curl -s --max-time 5 http://localhost:8080/health 2>/dev/null && echo "" || echo "未就绪"

echo -n "Embedding (8081): "
curl -s --max-time 5 http://localhost:8081/health 2>/dev/null && echo "" || echo "未就绪"

echo -n "API (5000): "
curl -s --max-time 10 http://localhost:5000/health 2>/dev/null || echo "未就绪"

echo ""
echo "===== 启动完成 ====="
echo "LLM PID: $LLM_PID | Embed PID: $EMBED_PID | API PID: $API_PID"
