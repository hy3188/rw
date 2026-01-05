# --------------------------------------------------------
# 阶段 1: 依赖构建层 (Build Stage)
# 使用 slim 版本而非 alpine，以获得更好的 glibc 兼容性 [11]
# --------------------------------------------------------
FROM node:20-slim AS builder

WORKDIR /app

# 复制依赖定义文件
COPY package.json package-lock.json*./

# 安装生产环境依赖 (CI 模式更严格)
RUN npm ci --only=production

# --------------------------------------------------------
# 阶段 2: 运行时镜像 (Runtime Stage)
# --------------------------------------------------------
FROM node:20-slim

WORKDIR /app

# 安装必要的系统工具
# ca-certificates: 用于 HTTPS 请求验证
# curl: 用于下载二进制文件
# iproute2: 用于网络调试 (ss, ip 命令)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 从构建层复制 node_modules
COPY --from=builder /app/node_modules./node_modules

# 复制应用源码和脚本
COPY src/./src/
COPY scripts/entrypoint.sh./

# 赋予脚本执行权限
RUN chmod +x./entrypoint.sh

# 设置环境变量默认值（可通过 docker run -e 覆盖）
ENV PORT=3000
ENV NODE_ENV=production

# 声明暴露端口
EXPOSE 3000

# 设置容器启动入口
ENTRYPOINT ["./entrypoint.sh"]
