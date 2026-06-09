#!/data/data/com.termux/files/usr/bin/bash
set -e

# ── bun-termux installer ──────────────────────────────────────────────────
#  Orchestrates modular patches from the patches/ directory.
#
#  Usage:
#    git clone https://github.com/Anon4You/bun-termux.git
#    cd bun-termux
#    bash install.sh
#
#  Supports PREFIX and BUN_VERSION env vars:
#    PREFIX=/data/data/com.termux/files/usr BUN_VERSION=1.3.14 bash install.sh
# ───────────────────────────────────────────────────────────────────────────

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BUN_VERSION="${BUN_VERSION:-1.3.14}"
PATCH_DIR="$(cd "$(dirname "$0")/patches" && pwd)"

export PREFIX BUN_VERSION PATCH_DIR

echo "bun-termux installer"
echo "  PREFIX=$PREFIX"
echo "  VERSION=$BUN_VERSION"
echo "  PATCHES=$PATCH_DIR"
echo ""

run_patch() {
    local name="$1"
    local file="$PATCH_DIR/$name"
    if [ -f "$file" ]; then
        bash "$file"
    else
        echo "  [SKIP] $file not found"
    fi
    echo ""
}

run_patch "00-check-deps.sh"
run_patch "01-check-arch.sh"
run_patch "02-setup-dirs.sh"
run_patch "03-download-bun.sh"
run_patch "06-compile-shims.sh"
run_patch "07-cleanup.sh"
run_patch "08-verify.sh"

echo "bun ${BUN_VERSION} installed successfully."
exit 0
