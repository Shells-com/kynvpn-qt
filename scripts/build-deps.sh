#!/usr/bin/env bash
# Build the non-Qt dependencies into out/deps/<name>:
#   - openssl   (all platforms; headers for Qt's -openssl-runtime backend)
#   - patchelf  (Linux; shipped in <qt>/bin)
#   - icu       (Linux; Qt links it, and it's bundled into <qt>/lib)
#
# Usage: build-deps.sh [component...]   (default: all for this platform)
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

export CC="${CC:-clang}" CXX="${CXX:-clang++}"
JOBS="$(calc_jobs 500)"

build_patchelf() {
    local src prefix="$DEPS_PREFIX/patchelf"
    src="$(extract_clean "$(fetch_verified "$(dep_source_file patchelf)" "$(dep_source_url patchelf)")" "$BUILD_DIR/patchelf")"
    apply_patches patchelf "$src"
    rm -rf "$prefix"
    (cd "$src" && ./configure --prefix="$prefix" && make -j"$JOBS" && make install)
    strip --strip-debug "$prefix/bin/patchelf"
    "$prefix/bin/patchelf" --version
}

build_icu() {
    local src prefix="$DEPS_PREFIX/icu" f
    src="$(extract_clean "$(fetch_verified "$(dep_source_file icu)" "$(dep_source_url icu)")" "$BUILD_DIR/icu")"
    apply_patches icu "$src"
    rm -rf "$prefix"
    mkdir -p "$BUILD_DIR/icu/make"
    (
        cd "$BUILD_DIR/icu/make"
        "$src/source/runConfigureICU" Linux --prefix="$prefix" --disable-tests --disable-samples
        make -j"$JOBS"
        make install
    )
    # Make the ICU binaries/libraries find each other wherever they're
    # installed (they're bundled into <qt>/lib).
    for f in "$prefix"/{bin,sbin,lib}/*; do
        if [ -f "$f" ] && [ ! -L "$f" ] && file "$f" | grep -q ELF; then
            # shellcheck disable=SC2016
            "$DEPS_PREFIX/patchelf/bin/patchelf" --set-rpath '$ORIGIN/../lib/' "$f"
        fi
    done
}

build_openssl() {
    local src prefix="$DEPS_PREFIX/openssl" target
    case "$PLATFORM-$ARCH" in
        linux-x86_64) target=linux-x86_64 ;;
        linux-arm64) target=linux-aarch64 ;;
        macos-x86_64) target=darwin64-x86_64-cc ;;
        # Only the headers are used (Qt loads libssl at runtime), and they're
        # the same for both 64-bit macOS architectures.
        macos-*) target=darwin64-arm64-cc ;;
    esac
    src="$(extract_clean "$(fetch_verified "$(dep_source_file openssl)" "$(dep_source_url openssl)")" "$BUILD_DIR/openssl")"
    apply_patches openssl "$src"
    rm -rf "$prefix"
    (
        cd "$src"
        ./Configure "$target" shared no-tests no-docs --prefix="$prefix" --libdir=lib
        make -j"$JOBS" build_libs
        make install_dev
    )
}

if [ "$#" -gt 0 ]; then
    components=("$@")
elif [ "$PLATFORM" = linux ]; then
    components=(patchelf icu openssl)
else
    components=(openssl)
fi

for c in "${components[@]}"; do
    log "Building $c"
    "build_$c"
    rm -rf "${BUILD_DIR:?}/$c"
done
