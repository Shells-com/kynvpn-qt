# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are used by the scripts sourcing this file
# Shared helpers for the build scripts.  Sourced, not executed.
#
# Platform detection and job calculation are adapted from
# pia-foss/desktop-dep-build util/platform.sh
# (Copyright (c) 2022 Private Internet Access, Inc., GPLv3).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.sh
source "$ROOT/config.sh"

die() { echo "error:" "$@" >&2; exit 1; }
log() { echo "==> $*" >&2; }
show_exec() { echo "+ $*" >&2; "$@"; }

case "$(uname -s)" in
    Linux)
        PLATFORM=linux
        case "$(uname -m)" in
            x86_64) ARCH=x86_64 ;;
            aarch64|arm64) ARCH=arm64 ;;
            *) die "Unsupported Linux architecture: $(uname -m)" ;;
        esac
        ;;
    Darwin)
        PLATFORM=macos
        # Qt 6 builds universal binaries in a single pass.  Set
        # MACOS_ARCHS=arm64 (or x86_64) for a single-architecture build.
        MACOS_ARCHS="${MACOS_ARCHS:-arm64;x86_64}"
        case "$MACOS_ARCHS" in
            *";"*) ARCH=universal ;;
            arm64|x86_64) ARCH="$MACOS_ARCHS" ;;
            *) die "Unsupported MACOS_ARCHS: $MACOS_ARCHS" ;;
        esac
        ;;
    *)
        die "Unsupported platform: $(uname -s)"
        ;;
esac

# Directory name of the Qt build inside <install>/<version>/, following the
# official installer layout.  The client looks for clang_64 / clang_arm64 /
# clang_universal (and gcc_*) here.
case "$ARCH" in
    x86_64) QT_BUILD_NAME=clang_64 ;;
    *) QT_BUILD_NAME="clang_$ARCH" ;;
esac

WORK="${WORK_DIR:-$ROOT/out}"
CACHE_DIR="$WORK/cache"
BUILD_DIR="$WORK/build"
DEPS_PREFIX="$WORK/deps"
INSTALL_BASE="$WORK/install"
QT_INSTALL_ROOT="$INSTALL_BASE/$QT_VERSION/$QT_BUILD_NAME"
ARTIFACTS_DIR="$WORK/artifacts"

PACKAGE_BASENAME="qt-$QT_VERSION-$DIST_NAME-$PLATFORM-$ARCH"

sha256_compat() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@"
    else
        shasum -a 256 "$@"
    fi
}

get_ncpus() {
    case "$PLATFORM" in
        macos) sysctl -n hw.ncpu ;;
        linux) nproc ;;
    esac
}

get_memmb() {
    local bytes
    case "$PLATFORM" in
        macos) bytes="$(sysctl -n hw.memsize)" ;;
        linux) bytes="$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 ))" ;;
    esac
    echo "$(( bytes / 1024 / 1024 ))"
}

# Number of parallel jobs: CPUs plus a few extra, but no more than one job
# per <arg> MB of RAM (link steps with debug info are memory hungry).
# JOBS in the environment overrides this.
calc_jobs() {
    if [ -n "${JOBS:-}" ]; then
        echo "$JOBS"
        return
    fi
    local per_job_mb="${1:-1000}" cpus extra cpu_jobs mem_jobs jobs
    cpus="$(get_ncpus)"
    extra=$(( cpus / 2 < 4 ? cpus / 2 : 4 ))
    cpu_jobs=$(( cpus + extra ))
    mem_jobs=$(( $(get_memmb) / per_job_mb ))
    jobs=$(( cpu_jobs < mem_jobs ? cpu_jobs : mem_jobs ))
    [ "$jobs" -ge 1 ] || jobs=1
    echo "Detected $cpus CPUs and $(get_memmb) MB RAM, using $jobs jobs" >&2
    echo "$jobs"
}

# Qt modules from config.sh that apply to this platform, in build order.
qt_modules_for_platform() {
    local entry name plat
    for entry in "${QT_MODULES[@]}"; do
        name="${entry%%:*}"
        plat=""
        if [ "$name" != "$entry" ]; then plat="${entry#*:}"; fi
        if [ -z "$plat" ] || [ "$plat" = "$PLATFORM" ]; then
            echo "$name"
        fi
    done
}

qt_source_file() { echo "$1-everywhere-src-$QT_VERSION.tar.xz"; }
qt_source_url() {
    local minor="${QT_VERSION%.*}"
    echo "https://download.qt.io/official_releases/qt/$minor/$QT_VERSION/submodules/$(qt_source_file "$1")"
}

# Source archive file name and download URL for a non-Qt dependency.
dep_source_file() {
    case "$1" in
        icu) echo "icu4c-$ICU_VERSION-sources.tgz" ;;
        openssl) echo "openssl-$OPENSSL_VERSION.tar.gz" ;;
        patchelf) echo "patchelf-$PATCHELF_VERSION.tar.gz" ;;
        *) die "Unknown dependency $1" ;;
    esac
}
dep_source_url() {
    case "$1" in
        icu) echo "https://github.com/unicode-org/icu/releases/download/release-$ICU_VERSION/$(dep_source_file icu)" ;;
        openssl) echo "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/$(dep_source_file openssl)" ;;
        patchelf) echo "https://github.com/NixOS/patchelf/releases/download/$PATCHELF_VERSION/$(dep_source_file patchelf)" ;;
        *) die "Unknown dependency $1" ;;
    esac
}

# Download <url> to the cache as <file> (if not already there) and verify it
# against the pinned hash in sources.sha256.  Prints the cached path.
fetch_verified() {
    local file="$1" url="$2" expected actual
    expected="$(awk -v f="$file" '$2 == f || $2 == "*" f { print $1 }' "$ROOT/sources.sha256")"
    [ -n "$expected" ] || die "No pinned hash for $file in sources.sha256"
    mkdir -p "$CACHE_DIR"
    if [ ! -f "$CACHE_DIR/$file" ]; then
        log "Downloading $url"
        curl -fL --retry 5 --retry-delay 10 -o "$CACHE_DIR/$file.part" "$url"
        mv "$CACHE_DIR/$file.part" "$CACHE_DIR/$file"
    fi
    actual="$(sha256_compat "$CACHE_DIR/$file" | awk '{print $1}')"
    if [ "$actual" != "$expected" ]; then
        rm -f "$CACHE_DIR/$file"
        die "Hash mismatch for $file: expected $expected, got $actual"
    fi
    echo "$CACHE_DIR/$file"
}

# Extract a verified archive into a fresh directory, returns the top-level
# directory it contained.
extract_clean() {
    local archive="$1" dest="$2"
    rm -rf "$dest"
    mkdir -p "$dest"
    tar -xf "$archive" -C "$dest"
    local top
    top="$(find "$dest" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [ -n "$top" ] || die "Archive $archive is empty"
    echo "$top"
}

# Apply patches/<component>/*.patch (if any) to a source tree.
apply_patches() {
    local component="$1" srcdir="$2" p
    for p in "$ROOT/patches/$component"/*.patch; do
        [ -e "$p" ] || continue
        log "Applying $(basename "$p")"
        patch -d "$srcdir" -p1 --forward --batch < "$p"
    done
}
