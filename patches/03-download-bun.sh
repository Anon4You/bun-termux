#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[patch 03] Downloading bun binary..."

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
ARCH=$(uname -m)

case "$ARCH" in
    aarch64) BUN_TARGET="linux-aarch64" ;;
    x86_64)  BUN_TARGET="linux-x86_64" ;;
    *) echo "  Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

VERSION="${BUN_VERSION:-1.3.14}"
DOWNLOAD_URL="https://github.com/oven-sh/bun/releases/download/bun-v${VERSION}/bun-${BUN_TARGET}.zip"
SHARE_DIR="$PREFIX/share/bun"
STAGING="$TMPDIR/bun-staging"

curl -fsSL -o "$STAGING/bun.zip" "$DOWNLOAD_URL"
echo "  Extracting..."
unzip -q "$STAGING/bun.zip" -d "$STAGING"

ORIG_BIN=$(find "$STAGING" -type f -name "bun" -executable | head -n1)
if [ -z "$ORIG_BIN" ]; then
    echo "  Error: bun binary not found in archive." >&2
    exit 1
fi

REAL_BIN="$SHARE_DIR/bun.real"
mv "$ORIG_BIN" "$REAL_BIN"
chmod +x "$REAL_BIN"
rm -rf "$STAGING"

echo "  Installed real binary: $REAL_BIN"
exit 0
