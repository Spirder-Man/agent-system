# ==========================================
# Agent1 Web - Vue 3 SPA (Nginx)
# 多阶段：Node 编译 → Nginx 静态托管 + 反向代理
# ==========================================
# 使用方式：
#   docker build -t agent1-web:latest ./agent1-web
#   docker compose up -d --build web
# ==========================================

FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

COPY . .
ARG VITE_API_BASE_URL=/
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# ════════════════════════════════════════
# Runtime：Nginx 托管 dist，/api 等到 api:8080
# ════════════════════════════════════════
FROM nginx:1.27-alpine AS runtime

RUN apk add --no-cache wget

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/nginx-health || exit 1

CMD ["nginx", "-g", "daemon off;"]
