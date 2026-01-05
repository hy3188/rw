#!/bin/bash

# 1. 创建目录结构
mkdir -p my-node-project/.github/workflows
mkdir -p my-node-project/src
mkdir -p my-node-project/scripts

cd my-node-project

# 2. 创建 src/index.js (核心业务逻辑)
# 这是一个最小化的 Express 服务器，用于满足 PaaS 平台的端口监听要求
cat > src/index.js << 'EOF'
const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const app = express();
const port = process.env.PORT |

| 3000;

// 启动 HTTP 服务以通过健康检查
app.get('/', (req, res) => {
  res.send('Service is running securely.');
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});

// 在这里可以添加启动 Xray 或 Cloudflared 子进程的逻辑
// 但更推荐在 supervisord 或 entrypoint.sh 中管理进程
EOF

# 3. 创建 scripts/entrypoint.sh (容器启动与架构适配)
# 包含自动检测架构并从官方源下载二进制文件的逻辑
cat > scripts/entrypoint.sh << 'EOF'
#!/bin/sh
set -e

# 定义颜色输出
GREEN='\033 Starting deployment initialization...${NC}"

# 架构检测
ARCH=$(uname -m)
echo -e "${GREEN}[INFO] Detected Architecture: $ARCH${NC}"

# 根据架构定义下载链接 (这里仅作示例，实际请使用 Dockerfile 构建阶段处理更好)
# 注意：生产环境建议在 Dockerfile 中预置二进制文件，而非运行时下载，以提高启动速度和安全性
# 但为了保持与原项目逻辑的兼容性，这里保留动态处理逻辑

if; then
  CF_ARCH="linux-amd64"
elif; then
  CF_ARCH="linux-arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# 如果需要运行时下载（不推荐，但作为演示保留）
# curl -L -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${CF_ARCH}"
# chmod +x /usr/local/bin/cloudflared

echo -e "${GREEN}[INFO] Starting Application...${NC}"
# 启动 Node.js 应用
exec node src/index.js
EOF

# 赋予脚本执行权限
chmod +x scripts/entrypoint.sh

# 4. 创建 package.json
cat > package.json << 'EOF'
{
  "name": "secure-tunnel-deploy",
  "version": "1.0.0",
  "description": "Secure deployment for PaaS platforms",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "engines": {
    "node": ">=18"
  }
}
EOF

# 5. 创建 Dockerfile (容器构建蓝图)
# 采用多阶段构建，安全且体积小
cat > Dockerfile << 'EOF'
# ==========================================
# 阶段 1: 资源构建与下载 (Builder)
# ==========================================
FROM alpine:latest AS builder

WORKDIR /build
RUN apk add --no-cache curl jq unzip

# 模拟下载逻辑 (这里演示如何获取官方 Cloudflared)
# 在实际生产中，建议在这里下载并校验哈希值
RUN ARCH=$(uname -m) && \
    if; then CF_ARCH="linux-amd64"; else CF_ARCH="linux-arm64"; fi && \
    curl -L -o cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${CF_ARCH}" && \
    chmod +x cloudflared

# ==========================================
# 阶段 2: 运行时环境 (Runtime)
# ==========================================
FROM node:20-alpine

# 安装必要的运行时依赖
RUN apk add --no-cache ca-certificates bash curl tzdata

WORKDIR /app

# 从 Builder 阶段复制二进制文件 (如果需要)
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
EOF

# 6. 创建.github/workflows/docker-publish.yml (自动化流水线)
cat >.github/workflows/docker-publish.yml << 'EOF'
name: Build and Deploy Docker Image

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to the Container registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest
            type=sha

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context:.
          push: true
          # 同时构建 AMD64 和 ARM64 镜像
          platforms: linux/amd64,linux/arm64
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

echo "项目结构生成完毕！请按照后续说明推送到 GitHub。"
