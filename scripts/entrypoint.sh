#!/bin/sh
set -e

ARCH="$(uname -m)"
echo "Detected Architecture: $ARCH"

if [ "$ARCH" = "x86_64" ]; then
  CF_ARCH="linux-amd64"
elif [ "$ARCH" = "aarch64" ]; then
  CF_ARCH="linux-arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

if [ ! -f "/usr/local/bin/cloudflared" ]; then
  echo "Downloading Cloudflared for $CF_ARCH..."
  curl -L -o /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-$CF_ARCH"
  chmod +x /usr/local/bin/cloudflared
fi

echo "Starting Node.js application..."
exec node src/index.js
