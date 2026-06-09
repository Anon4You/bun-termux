#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[patch 00] Checking dependencies..."

DEPS=(curl unzip clang)
MISSING=()
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  Installing missing dependencies: ${MISSING[*]}"
    apt install -y "${MISSING[@]}"
fi

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
if [ ! -d "$PREFIX/glibc/lib" ]; then
    echo "  Installing glibc-repo and glibc..."
    apt install -y glibc-repo glibc
fi

echo "  All dependencies found."
exit 0
