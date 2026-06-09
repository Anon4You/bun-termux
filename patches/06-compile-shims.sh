#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[patch 06] Compiling shims..."

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
LIB_DIR="$PREFIX/lib"
BIN_DIR="$PREFIX/bin"
ARCH=$(uname -m)

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"

clang -O2 -fPIC -shared -nostdlib \
    -o "$LIB_DIR/bun-shim.so" \
    "$PATCH_DIR/04-bun-shim.c"
chmod +x "$LIB_DIR/bun-shim.so"
echo "  Compiled: $LIB_DIR/bun-shim.so"

# Determine correct ld-so for wrapper
case "$ARCH" in
    aarch64) WRAPPER_LD_SO="ld-linux-aarch64.so.1" ;;
    x86_64)  WRAPPER_LD_SO="ld-linux-x86-64.so.2" ;;
esac

# Patch the wrapper with the correct ld-so
sed "s|\"ld-linux-aarch64.so.1\"|\"$WRAPPER_LD_SO\"|" \
    "$PATCH_DIR/05-bun-wrapper.c" > "$TMPDIR/bun-wrapper-arch.c"

clang -O2 -o "$BIN_DIR/bun" "$TMPDIR/bun-wrapper-arch.c"
chmod +x "$BIN_DIR/bun"
echo "  Compiled: $BIN_DIR/bun"

exit 0
