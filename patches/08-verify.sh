#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[patch 08] Verifying installation..."

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

if [ -x "$PREFIX/bin/bun" ]; then
    echo "  Wrapper: $PREFIX/bin/bun ... OK"
else
    echo "  ERROR: $PREFIX/bin/bun not found or not executable." >&2
    exit 1
fi

if [ -f "$PREFIX/share/bun/bun.real" ]; then
    echo "  Real binary: $PREFIX/share/bun/bun.real ... OK"
else
    echo "  ERROR: $PREFIX/share/bun/bun.real not found." >&2
    exit 1
fi

if [ -f "$PREFIX/lib/bun-shim.so" ]; then
    echo "  LD_PRELOAD shim: $PREFIX/lib/bun-shim.so ... OK"
else
    echo "  ERROR: $PREFIX/lib/bun-shim.so not found." >&2
    exit 1
fi

echo "  All checks passed."
exit 0
