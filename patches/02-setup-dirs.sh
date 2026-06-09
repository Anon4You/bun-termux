#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[patch 02] Setting up directories..."

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SHARE_DIR="$PREFIX/share/bun"
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib"
STAGING="$TMPDIR/bun-staging"

mkdir -p "$SHARE_DIR" "$BIN_DIR" "$LIB_DIR" "$STAGING"
mkdir -p "$HOME/.bun/cache" "$HOME/.bun/install/cache" "$HOME/.cache"

echo "  SHARE_DIR=$SHARE_DIR"
echo "  BIN_DIR=$BIN_DIR"
echo "  LIB_DIR=$LIB_DIR"
exit 0
