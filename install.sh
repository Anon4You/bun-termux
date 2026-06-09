#!/data/data/com.termux/files/usr/bin/bash
set -e

# ── bun-termux installer ──────────────────────────────────────────────────
#  Self-contained script for one-liner curl-pipe-bash usage:
#    curl -fsSL https://raw.githubusercontent.com/your/bun-termux/main/install.sh | bash
#
#  Supports PREFIX and BUN_VERSION env vars:
#    PREFIX=/data/data/com.termux/files/usr BUN_VERSION=1.3.14 bash install.sh
#
#  Modular patches kept in ./patches/ for reference & offline use.
# ───────────────────────────────────────────────────────────────────────────

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BUN_VERSION="${BUN_VERSION:-1.3.14}"
SHARE_DIR="$PREFIX/share/bun"
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib"
STAGING="$TMPDIR/bun-staging"

echo "bun-termux installer"
echo "  PREFIX=$PREFIX"
echo "  VERSION=$BUN_VERSION"
echo ""

# ── patch 00: check dependencies ──────────────────────────────────────────
echo "[patch 00] Checking dependencies..."
DEPS=(curl unzip clang)
MISSING=()
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  Missing dependencies: ${MISSING[*]}" >&2
    echo "  Install: pkg install ${MISSING[*]}" >&2
    exit 1
fi
echo "  All dependencies found."
echo ""

# ── patch 01: check architecture ─────────────────────────────────────────
echo "[patch 01] Checking architecture..."
ARCH=$(uname -m)
case "$ARCH" in
    aarch64) LD_SO="ld-linux-aarch64.so.1"; BUN_TARGET="linux-aarch64" ;;
    x86_64)  LD_SO="ld-linux-x86-64.so.2"; BUN_TARGET="linux-x86_64" ;;
    *) echo "  Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
echo "  Arch: $ARCH  Target: $BUN_TARGET"
echo ""

# ── patch 02: create directories ─────────────────────────────────────────
echo "[patch 02] Creating directories..."
mkdir -p "$SHARE_DIR" "$BIN_DIR" "$LIB_DIR" "$STAGING"
mkdir -p "$HOME/.bun/cache" "$HOME/.bun/install/cache" "$HOME/.cache"
echo "  $SHARE_DIR"
echo "  $BIN_DIR"
echo "  $LIB_DIR"
echo ""

# ── patch 03: download bun binary ────────────────────────────────────────
echo "[patch 03] Downloading bun binary..."
DOWNLOAD_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-${BUN_TARGET}.zip"
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
echo "  Installed: $REAL_BIN"
echo ""

# ── patch 04: compile LD_PRELOAD shim ────────────────────────────────────
echo "[patch 04] Compiling LD_PRELOAD shim..."
cat > "$TMPDIR/bun-shim.c" << 'SHIMEOF'
#include <stdarg.h>
#include <fcntl.h>
#include <sys/syscall.h>
#include <unistd.h>

extern int *__errno_location(void);
#define errno (*__errno_location())

static long sc(long n, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register long x4 __asm__("x4") = a5;
    register long x5 __asm__("x5") = a6;
    register long r __asm__("x8") = n;
    __asm__ volatile("svc #0" : "+r"(r), "+r"(x0), "+r"(x1), "+r"(x2), "+r"(x3), "+r"(x4), "+r"(x5) : : "memory");
    return x0;
}
#define SOPENAT(d,p,f,m) sc(SYS_openat, (long)(d), (long)(p), (long)(f), (long)(m), 0, 0)
#define SFSTATAT(d,p,b,f) sc(SYS_newfstatat, (long)(d), (long)(p), (long)(b), (long)(f), 0, 0)
#define SACCESS(p,m) sc(SYS_faccessat, (long)(AT_FDCWD), (long)(p), (long)(m), 0, 0, 0)

static const char *prefix = "/data/data/com.termux/files/home/";
static int home_fd = -1;

__attribute__((constructor))
static void init(void) {
    home_fd = SOPENAT(AT_FDCWD, "/data/data/com.termux/files/home",
                      O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
}

static int is_rooted(const char *p) {
    if (!p || p[0] != '/') return 0;
    if (p[1] == '\0') return 1;
    if (p[1]=='d' && p[2]=='a' && p[3]=='t' && p[4]=='a') {
        if (p[5]=='\0' || (p[5]=='/' && p[6]=='\0')) return 1;
        if (p[5]=='/' && p[6]=='d' && p[7]=='a' && p[8]=='t' && p[9]=='a') {
            if (p[10]=='\0' || (p[10]=='/' && p[11]=='\0')) return 1;
        }
    }
    return 0;
}

static int under_home(const char *p) {
    if (!p) return 0;
    const char *a = prefix;
    const char *b = p;
    while (*a && *b && *a == *b) { a++; b++; }
    return *a == '\0' && (*b != '\0');
}

static int set_errno(long r) {
    if (r >= 0) return (int)r;
    errno = (int)(-r);
    return -1;
}

static int redirect_openat(int dirfd, const char *p, int flags, mode_t m) {
    if (p && p[0] == '/') {
        if (is_rooted(p) && home_fd >= 0)
            return set_errno(SOPENAT(home_fd, ".", flags, m));
        if (under_home(p) && home_fd >= 0)
            return set_errno(SOPENAT(home_fd, p + (sizeof("/data/data/com.termux/files/home/")-1), flags, m));
    }
    return set_errno(SOPENAT(dirfd, p, flags, m));
}

int openat(int dirfd, const char *p, int flags, ...) {
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode_t m = va_arg(ap, mode_t); va_end(ap);
        return redirect_openat(dirfd, p, flags, m);
    }
    return redirect_openat(dirfd, p, flags, 0);
}
int openat64(int dirfd, const char *p, int flags, ...) {
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode_t m = va_arg(ap, mode_t); va_end(ap);
        return redirect_openat(dirfd, p, flags, m);
    }
    return redirect_openat(dirfd, p, flags, 0);
}
int open(const char *p, int flags, ...) {
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode_t m = va_arg(ap, mode_t); va_end(ap);
        return redirect_openat(AT_FDCWD, p, flags, m);
    }
    return redirect_openat(AT_FDCWD, p, flags, 0);
}
int open64(const char *p, int flags, ...) {
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode_t m = va_arg(ap, mode_t); va_end(ap);
        return redirect_openat(AT_FDCWD, p, flags, m);
    }
    return redirect_openat(AT_FDCWD, p, flags, 0);
}

static int redirect_stat(int dirfd, const char *p, struct stat *b, int fl) {
    if (p && p[0] == '/') {
        if (is_rooted(p) && home_fd >= 0)
            return set_errno(SFSTATAT(home_fd, ".", (long)b, fl));
        if (under_home(p) && home_fd >= 0)
            return set_errno(SFSTATAT(home_fd, p + (sizeof("/data/data/com.termux/files/home/")-1), (long)b, fl));
    }
    return set_errno(SFSTATAT(dirfd, p, (long)b, fl));
}

int newfstatat(int dirfd, const char *p, struct stat *b, int fl) {
    return redirect_stat(dirfd, p, b, fl);
}
int fstatat64(int dirfd, const char *p, struct stat *b, int fl) {
    return redirect_stat(dirfd, p, b, fl);
}
int __fxstatat(int ver, int dirfd, const char *p, struct stat *b, int fl) {
    return redirect_stat(dirfd, p, b, fl);
}
int stat(const char *p, struct stat *b) {
    return redirect_stat(AT_FDCWD, p, b, 0);
}
int lstat(const char *p, struct stat *b) {
    return redirect_stat(AT_FDCWD, p, b, AT_SYMLINK_NOFOLLOW);
}
int fstatat(int dirfd, const char *p, struct stat *b, int fl) {
    return redirect_stat(dirfd, p, b, fl);
}

static int redirect_access(const char *p, int mode) {
    if (p && p[0] == '/') {
        if (is_rooted(p)) return set_errno(0);
        if (under_home(p) && home_fd >= 0)
            return set_errno(SACCESS(p + (sizeof("/data/data/com.termux/files/home/")-1), mode));
    }
    return set_errno(SACCESS(p, mode));
}

int faccessat(int dirfd, const char *p, int mode, int flags) {
    (void)dirfd; (void)flags;
    return redirect_access(p, mode);
}
int access(const char *p, int mode) {
    return redirect_access(p, mode);
}
SHIMEOF

clang -O2 -fPIC -shared -nostdlib -o "$LIB_DIR/bun-shim.so" "$TMPDIR/bun-shim.c"
chmod +x "$LIB_DIR/bun-shim.so"
echo "  Compiled: $LIB_DIR/bun-shim.so"
echo ""

# ── patch 05: compile wrapper binary ─────────────────────────────────────
echo "[patch 05] Compiling wrapper binary..."
cat > "$TMPDIR/bun_wrapper.c" << WRAPEOF
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>

int main(int argc, char** argv) {
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");

    setenv("HOME", "/data/data/com.termux/files/home", 1);
    setenv("BUN_INSTALL_CACHE_DIR", "/data/data/com.termux/files/home/.bun/cache", 1);
    setenv("XDG_CACHE_HOME", "/data/data/com.termux/files/home/.cache", 1);
    setenv("TMPDIR", "/data/data/com.termux/files/usr/tmp", 1);
    setenv("BUN_MANIFEST_CACHE", "/data/data/com.termux/files/home/.cache/bun/manifest", 0);
    setenv("SSL_CERT_FILE", "/data/data/com.termux/files/usr/etc/tls/cert.pem", 1);
    setenv("BUN_OPTIONS", "--backend=copyfile", 0);

    char* lib_path = "/data/data/com.termux/files/usr/glibc/lib";
    char* shim_path = "/data/data/com.termux/files/usr/lib/bun-shim.so";

    static const char* LD_SO = "$LD_SO";
    char loader[PATH_MAX];
    snprintf(loader, sizeof(loader), "/data/data/com.termux/files/usr/glibc/lib/%s", LD_SO);
    char* real_bin = "/data/data/com.termux/files/usr/share/bun/bun.real";

    char** new_argv = malloc((argc + 6) * sizeof(char*));
    if (!new_argv) return 1;
    new_argv[0] = loader;
    new_argv[1] = "--library-path";
    new_argv[2] = lib_path;
    new_argv[3] = "--preload";
    new_argv[4] = shim_path;
    new_argv[5] = real_bin;
    for (int i = 1; i < argc; i++) new_argv[i + 5] = argv[i];
    new_argv[argc + 5] = NULL;

    execv(loader, new_argv);
    perror("execv");
    free(new_argv);
    return 1;
}
WRAPEOF

clang -O2 -o "$BIN_DIR/bun" "$TMPDIR/bun_wrapper.c"
chmod +x "$BIN_DIR/bun"
echo "  Compiled: $BIN_DIR/bun"
echo ""

# ── patch 06: cleanup ────────────────────────────────────────────────────
echo "[patch 06] Cleaning up..."
rm -f "$TMPDIR/bun-shim.c" "$TMPDIR/bun_wrapper.c"
echo "  Done."
echo ""

# ── patch 07: verify installation ────────────────────────────────────────
echo "[patch 07] Verifying installation..."
FAIL=0
if [ ! -x "$BIN_DIR/bun" ]; then
    echo "  ERROR: $BIN_DIR/bun missing or not executable." >&2
    FAIL=1
fi
if [ ! -f "$SHARE_DIR/bun.real" ]; then
    echo "  ERROR: $SHARE_DIR/bun.real not found." >&2
    FAIL=1
fi
if [ ! -f "$LIB_DIR/bun-shim.so" ]; then
    echo "  ERROR: $LIB_DIR/bun-shim.so not found." >&2
    FAIL=1
fi
if [ "$FAIL" = 1 ]; then
    exit 1
fi
echo "  All checks passed."
echo ""

echo "bun ${BUN_VERSION} installed successfully."
exit 0
