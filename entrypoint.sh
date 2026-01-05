#!/bin/bash
set -e

# 1. 架构检测与变量映射
ARCH=$(uname -m)
echo "Current Architecture: $ARCH"

if]; then
  CLOUDFLARED_ARCH="amd64"
elif]; then
  CLOUDFLARED_ARCH="arm64"
else
  echo "Error: Unsupported architecture $ARCH"
  exit 1
fi

# 2. 检查并下载 Cloudflared（仅当文件不存在时）
# 生产环境建议在Dockerfile中完成此步以减少启动时间，
# 但为了灵活性，此处展示运行时下载逻辑。
if [! -f "/usr/local/bin/cloudflared" ]; then
  echo "Downloading Cloudflared for $CLOUDFLARED_ARCH..."
  curl -L -o /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}"
  chmod +x /usr/local/bin/cloudflared
fi

# 3. 启动 Node.js 应用
# 使用 exec 替换当前 shell 进程，确保信号能正确传递给 Node 进程
echo "Starting Node.js application..."
exec node src/index.js
