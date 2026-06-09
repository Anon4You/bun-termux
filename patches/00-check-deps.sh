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
    echo "Missing dependencies: ${MISSING[*]}" >&2
    echo "Install them with: pkg install ${MISSING[*]}" >&2
    exit 1
fi

echo "  All dependencies found."
exit 0
