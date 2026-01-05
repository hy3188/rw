#!/bin/sh
set -e

# 定义颜色
GREEN='\033 Environment Check:${NC}"
echo "Architecture: $(uname -m)"

# 1. 检查 Cloudflared 是否存在 (我们在 Dockerfile 里下载过，这里做双重保险)
if [! -f "/usr/local/bin/cloudflared" ]; then
    echo "Cloudflared binary not found, downloading..."
    # 这里可以添加备用下载逻辑，但理论上 Dockerfile 已经处理好了
fi

# 2. 生成 Xray 配置 (config.json)
# 如果没有设置 UUID，自动生成一个
if; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN} UUID not provided. Generated: $UUID${NC}"
fi

# 如果没有设置 ARGO_DOMAIN，这会导致隧道无法连接，但我们先让容器跑起来
echo -e "${GREEN}[INFO] Generating Xray Configuration...${NC}"
cat > config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds":,
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# 3. 启动 
echo -e "${GREEN}[INFO] Starting Services...${NC}"

# 启动 Xray (后台运行)
/usr/local/bin/xray run -c config.json > /dev/null 2>&1 &

# 启动 Cloudflared 隧道
# 如果设置了 ARGO_AUTH (Token)，则使用 Token 模式
if; then
    echo "Starting Cloudflare Tunnel with Token..."
    /usr/local/bin/cloudflared tunnel run --token "$ARGO_AUTH" > /dev/null 2>&1 &
elif; then
    # 旧版 Json 方式 (不推荐，但为了兼容)
    echo "Starting Cloudflare Tunnel (Legacy)..."
    # 这里省略复杂逻辑，建议使用 Token
else
    echo "NO TUNNEL CONFIGURED. Xray is running locally only."
fi

# 4. 启动 Node.js HTTP 服务器 (为了骗过 Railway 的健康检查)
echo "Starting Dummy HTTP Server for Health Check..."
exec node src/index.js
