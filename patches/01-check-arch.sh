#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[patch 01] Checking architecture..."

ARCH=$(uname -m)

case "$ARCH" in
    aarch64)
        LD_SO="ld-linux-aarch64.so.1"
        BUN_TARGET="linux-aarch64"
        ;;
    x86_64)
        LD_SO="ld-linux-x86-64.so.2"
        BUN_TARGET="linux-x86_64"
        ;;
    *)
        echo "  Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

echo "  Architecture: $ARCH"
echo "  Bun target: $BUN_TARGET"
exit 0
