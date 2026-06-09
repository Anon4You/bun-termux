<p align="center">
  <img src="https://github.com/user-attachments/assets/50282090-adfd-4ddb-9e27-c30753c6b161" alt="bun-termux" width="200">
</p>

# bun-termux

**Bun** runtime for **Termux** via glibc — install the official Linux binary alongside a minimal LD_PRELOAD shim to work around Termux permission constraints.

## Features

- Downloads the official [bun](https://bun.sh) release (aarch64 / x86_64)
- Wraps it through the glibc dynamic linker with Termux-compatible environment variables
- Injects a lightweight LD_PRELOAD shim that redirects EACCES-prone file operations under `$HOME` to relative paths
- Fully uninstallable — removes all installed files cleanly

## Prerequisites

- Termux with [glibc](https://packages.termux.dev/glibc/) installed (`pkg install glibc`)
- `curl`, `unzip`, `clang` — installed automatically if missing

## Install

### One-liner (recommended)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Anon4You/bun-termux/main/install.sh)"
```

### Manual

```bash
git clone https://github.com/Anon4You/bun-termux.git
cd bun-termux
bash install.sh
```

Custom prefix or version:

```bash
PREFIX=/data/data/com.termux/files/usr BUN_VERSION=1.3.14 bash install.sh
```

## Structure

```
install.sh          # Self-contained installer (curl-pipe-bash compatible)
patches/
  00-check-deps.sh  # Verify curl, unzip, clang are available
  01-check-arch.sh  # Detect aarch64 / x86_64
  02-setup-dirs.sh  # Create share/bun, bin, lib, cache directories
  03-download-bun.sh # Fetch and extract bun binary from GitHub releases
  04-bun-shim.c     # LD_PRELOAD shim source (EACCES workaround)
  05-bun-wrapper.c  # Wrapper binary source (glibc loader + env setup)
  06-compile-shims.sh  # Compile C sources into .so and wrapper
  07-cleanup.sh     # Remove temporary build files
  08-verify.sh      # Validate all installed components
```

## How it works

1. **bun.real** – the official Linux binary, stored in `$PREFIX/share/bun/`
2. **bun** (wrapper) – a small C binary at `$PREFIX/bin/bun` that unsets `LD_PRELOAD`, sets Termux-friendly env vars (`HOME`, `TMPDIR`, `SSL_CERT_FILE`, etc.), then execs `bun.real` via the glibc loader with the shim preloaded
3. **bun-shim.so** – an LD_PRELOAD library that intercepts `open`, `stat`, and `access` syscalls on paths under `/data/data/com.termux/files/home/`, re-issuing them relative to an open file descriptor to bypass EACCES

## Uninstall

```bash
rm -f $PREFIX/bin/bun
rm -rf $PREFIX/share/bun
```

Or use the Debian package's `postrm` equivalent at `bun-deb/DEBIAN/postrm`.

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">Created by <a href="https://github.com/Anon4You">Anon4You</a></p>
