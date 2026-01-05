# ==========================================
# 阶段 1: 资源下载 (Builder)
# ==========================================
FROM alpine:latest AS builder

# 这里 ARG TARGETARCH 会自动由 Buildx 传入 (amd64 或 arm64)
ARG TARGETARCH

WORKDIR /build
RUN apk add --no-cache curl jq unzip

# 优化后的下载逻辑：直接利用 Docker 传入的架构名称
# Cloudflare 官方文件名为 cloudflared-linux-amd64 或 cloudflared-linux-arm64
# 这与 Docker 的 TARGETARCH (amd64/arm64) 完美对应
RUN echo "Building for architecture: linux-${TARGETARCH}" && \
    curl -L -o cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}" && \
    chmod +x cloudflared

# ==========================================
# 阶段 2: 运行时环境 (Runtime)
# ==========================================
FROM node:20-alpine

# 安装必要的运行时依赖
RUN apk add --no-cache ca-certificates bash curl tzdata

WORKDIR /app

# 从 Builder 阶段复制二进制文件
COPY --from=builder /build/cloudflared /usr/local/bin/cloudflared

# 复制项目文件
COPY package.json.
RUN npm install --production

COPY src/ src/
COPY scripts/ scripts/

# 赋予脚本执行权限
RUN chmod +x scripts/entrypoint.sh

# 环境变量设置
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# 启动入口
ENTRYPOINT ["./scripts/entrypoint.sh"]
