/*
 * patch 05: bun wrapper binary
 *
 * Cleans up LD_PRELOAD/LD_LIBRARY_PATH, sets Termux-appropriate
 * environment variables, then invokes the real bun binary through
 * the glibc dynamic loader with the shim preloaded.
 */
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

    static const char* LD_SO = "ld-linux-aarch64.so.1";
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
