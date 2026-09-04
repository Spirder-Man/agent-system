#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Agent1 一键容器化部署（后端 + 前端）
# 启动: PostgreSQL + llama.cpp(LLM+Embedding+Vision GPU) + API + Web
# 用法:
#   bash scripts/docker-up.sh          # GPU（默认）
#   bash scripts/docker-up.sh gpu
#   bash scripts/docker-up.sh cpu
# Windows 无 WSL bash 时请用:
#   powershell -File scripts/docker-up.ps1 cpu
# ═══════════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODE="${1:-gpu}"

cd "$PROJECT_DIR"

if [ "$MODE" != "gpu" ] && [ "$MODE" != "cpu" ]; then
    echo "❌ 未知模式: $MODE"
    echo "   用法: bash scripts/docker-up.sh [gpu|cpu]"
    exit 1
fi

COMPOSE_FILES=(-f docker-compose.yml)
if [ "$MODE" = "cpu" ]; then
    COMPOSE_FILES+=(-f docker-compose.cpu.yml)
fi

echo "════════════════════════════════════════"
echo "  Agent1 容器化部署（后端 + 前端 / ${MODE}）"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════"

# 1. 检查 .env 文件
if [ ! -f ".env" ]; then
    echo ""
    echo "⚠️  未找到 .env 文件，从 .env.example 复制..."
    cp .env.example .env
    echo "✅ .env 已创建，请编辑填入生产密码后重新执行"
    echo "   必填项: DB_PASSWORD / JWT_KEY"
    exit 1
fi

# 2. 加载环境变量
echo ""
echo "📋 加载环境变量..."
set -a; source .env; set +a

# 3. 检查 Docker
echo "🐳 检查 Docker..."
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker"
    exit 1
fi
echo "   Docker ✅"

# 4. 检查 GPU（gpu 模式提示，cpu 模式跳过预约）
if [ "$MODE" = "gpu" ]; then
    if command -v nvidia-smi > /dev/null 2>&1; then
        GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l)
        if [ "$GPU_COUNT" -gt 0 ]; then
            echo "   GPU: $GPU_COUNT 卡检测到 → llama-server / llama-vision 将使用 GPU（-ngl 99）"
            echo "   Embedding 默认 CPU（-ngl 0）。8B+VL 同卡建议 24GB 显存（3090）"
        else
            echo "   ⚠️  未检测到 GPU，可改用: bash scripts/docker-up.sh cpu"
        fi
    else
        echo "   ⚠️  nvidia-smi 不可用，GPU 直通可能失败；Windows 请用 cpu 模式"
    fi
else
    echo "   模式: CPU（llama.cpp 无 CUDA / 不申请 GPU / 不起视觉）"
    export ENABLE_VISION_OCR=false
fi

echo "   Host KNOWLEDGE_BASE_PATH: ${KNOWLEDGE_BASE_PATH:-./knowledgebase} → container /app/knowledgebase"

MODEL_ROOT="${MODELS_PATH:-$PROJECT_DIR/models}"
if [ "$MODE" = "gpu" ]; then
    if [ ! -f "$MODEL_ROOT/Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf" ] || [ ! -f "$MODEL_ROOT/mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf" ]; then
        echo "   ⚠️  缺少 VL GGUF（Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf + mmproj）"
        echo "   llama-vision 将不健康；OCR / 识图不可用"
    else
        echo "   VL + mmproj 已找到（8083）"
    fi
fi

# 5. 拉取镜像 + 构建后端与前端
echo ""
echo "📦 拉取 PostgreSQL 镜像..."
docker compose "${COMPOSE_FILES[@]}" pull postgres 2>/dev/null || true

if [ "$MODE" = "cpu" ]; then
    echo "🔨 构建 llama.cpp CPU 镜像 (首次约数分钟)..."
    docker compose "${COMPOSE_FILES[@]}" build llama-server llama-embed
else
    echo "🔨 构建 llama.cpp CUDA 镜像 (首次约10分钟，约 8G)..."
    docker compose "${COMPOSE_FILES[@]}" build llama-server llama-embed llama-vision
fi

echo "🔨 构建 API 镜像..."
docker compose "${COMPOSE_FILES[@]}" build api

echo "🔨 构建 Web 镜像..."
docker compose "${COMPOSE_FILES[@]}" build web

# 6. 启动后端 + 前端
echo ""
if [ "$MODE" = "gpu" ]; then
    echo "🚀 启动 postgres / llama-server / llama-embed / llama-vision / api / web ..."
    docker compose "${COMPOSE_FILES[@]}" up -d postgres llama-server llama-embed llama-vision api web
else
    echo "🚀 启动 postgres / llama-server / llama-embed / api / web（不起视觉）..."
    docker compose "${COMPOSE_FILES[@]}" up -d postgres llama-server llama-embed api web
fi

# 7. 等待健康检查通过
echo ""
echo "⏳ 等待服务就绪..."
echo "   PostgreSQL..."
until docker compose "${COMPOSE_FILES[@]}" exec -T postgres pg_isready -U "${DB_USERNAME:-postgres}" 2>/dev/null; do sleep 2; done
echo "   PostgreSQL ✅"

echo "   llama-server / llama-embed（等待模型加载）..."

API_HOST_PORT="${API_PORT:-5000}"
echo "   API (等待 http://localhost:${API_HOST_PORT}/health/live)..."
API_OK=0
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${API_HOST_PORT}/health/live" 2>/dev/null | grep -q '^200$'; then
        echo "   API ✅"
        API_OK=1
        break
    fi
    sleep 3
done
if [ "$API_OK" != "1" ]; then
    echo "   ⚠️  API 尚未通过健康检查，请查看: docker compose logs api llama-server"
fi

WEB_HOST_PORT="${WEB_PORT:-80}"
echo "   Web (等待 http://localhost:${WEB_HOST_PORT}/nginx-health)..."
WEB_OK=0
for i in $(seq 1 20); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WEB_HOST_PORT}/nginx-health" 2>/dev/null | grep -q '^200$'; then
        echo "   Web ✅"
        WEB_OK=1
        break
    fi
    sleep 2
done
if [ "$WEB_OK" != "1" ]; then
    echo "   ⚠️  Web 尚未通过健康检查，请查看: docker compose logs web"
fi

# 8. 打印状态
echo ""
echo "════════════════════════════════════════"
echo "  Agent1 后端 + 前端部署完成（${MODE}）"
echo "════════════════════════════════════════"
echo ""
echo "  服务入口:"
echo "  ┌─────────────────────────────────────"
echo "  │ Web 前端:         http://localhost:${WEB_HOST_PORT}"
echo "  │ API (Swagger):    http://localhost:${API_HOST_PORT}/swagger"
echo "  │ API (Health):     http://localhost:${API_HOST_PORT}/health"
echo "  │ API (Metrics):    http://localhost:${API_HOST_PORT}/metrics"
echo "  │ PostgreSQL:       localhost:${DB_PORT:-5432}"
echo "  │ llama.cpp LLM:    http://localhost:${LLAMA_PORT:-8080}"
echo "  │ llama.cpp Embed:  http://localhost:${LLAMA_EMBED_PORT:-8081}"
if [ "$MODE" = "gpu" ]; then
echo "  │ llama.cpp Vision: http://localhost:${LLAMA_VISION_PORT:-8083}"
fi
echo "  └─────────────────────────────────────"
echo ""
echo "  可选观测栈:"
echo "  docker compose -f docker-compose.yml $([ "$MODE" = "cpu" ] && echo "-f docker-compose.cpu.yml ") -f docker-compose.obs.yml up -d"
echo ""
echo "  常用命令:"
echo "  docker compose ${COMPOSE_FILES[*]} logs -f api      查看 API 实时日志"
echo "  docker compose ${COMPOSE_FILES[*]} logs -f web      查看 Web 实时日志"
echo "  docker compose ${COMPOSE_FILES[*]} restart api      重启 API"
echo "  docker compose ${COMPOSE_FILES[*]} down             停止全部服务"
echo "  docker compose ${COMPOSE_FILES[*]} down -v          停止+清除所有数据卷"
echo ""
echo "  状态检查:"
docker compose "${COMPOSE_FILES[@]}" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose "${COMPOSE_FILES[@]}" ps
