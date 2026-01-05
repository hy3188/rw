# ==========================================
# Stage 1: Resource Downloader (Builder)
# ==========================================
FROM alpine:latest AS builder

# 自动获取目标架构 (amd64 或 arm64)
ARG TARGETARCH

WORKDIR /build
RUN apk add --no-cache curl jq unzip

# 核心修正：根据 TARGETARCH 动态下载对应的 Cloudflare 版本
# 官方文件名格式为: cloudflared-linux-amd64 或 cloudflared-linux-arm64
RUN echo "Building for architecture: linux-${TARGETARCH}" && \
    curl -L -o cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}" && \
    chmod +x cloudflared

# ==========================================
# Stage 2: Runtime Environment
# ==========================================
FROM node:20-alpine

RUN apk add --no-cache ca-certificates bash curl tzdata

WORKDIR /app

# 从 Builder 阶段复制自动匹配架构的二进制文件
COPY --from=builder /build/cloudflared /usr/local/bin/cloudflared

COPY package.json.
RUN npm install --production

COPY src/ src/
COPY scripts/ scripts/

RUN chmod +x scripts/entrypoint.sh

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

ENTRYPOINT ["./scripts/entrypoint.sh"]
