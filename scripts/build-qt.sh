#!/usr/bin/env bash
# Build Qt modules and install them into out/install/<version>/<build_name>.
#
# Usage: build-qt.sh [--resume] [--until <module>] [module...]
#
# With no module arguments, builds every module listed in config.sh (for this
# platform) in order.
#   --resume          skip modules that are already installed
#   --until <module>  stop after building <module>
# CI uses these to split the build over several jobs (GitHub-hosted runners
# have a 6 hour limit per job).  Modules can also be listed explicitly; qtbase
# must be built first, and each module's dependencies must already be
# installed.
#
# The configure options follow pia-foss/desktop-dep-build
# (components/qt/build-linux.sh), translated to Qt 6 where needed.  See
# README.md for the full mapping.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

JOBS="$(calc_jobs 1000)"
export CC="${CC:-clang}" CXX="${CXX:-clang++}"

RESUME=""
UNTIL=""
modules=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --resume) RESUME=1; shift ;;
        --until) UNTIL="${2:?--until needs a module name}"; shift 2 ;;
        -*) die "Unknown option $1" ;;
        *) modules+=("$1"); shift ;;
    esac
done
if [ "${#modules[@]}" -eq 0 ]; then
    while IFS= read -r m; do modules+=("$m"); done < <(qt_modules_for_platform)
fi
if [ -n "$UNTIL" ]; then
    found=""
    for m in "${modules[@]}"; do [ "$m" = "$UNTIL" ] && found=1; done
    [ -n "$found" ] || die "--until $UNTIL: not one of the modules to build (${modules[*]})"
fi

BUILD_INFO_DIR="$QT_INSTALL_ROOT/share/qt-build-info"

# Extra CMake arguments for every module.
COMMON_CMAKE_ARGS=()
if [ "$PLATFORM" = macos ]; then
    # GitHub's macOS images have a lot of Homebrew packages installed.  Keep
    # Qt from picking any of them up (pia-foss warns about the same problem
    # with libxcb), so the result only depends on the macOS SDK.
    COMMON_CMAKE_ARGS+=("-DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew;/usr/local;/opt/local")
fi

configure_qtbase() {
    local src="$1"
    local args=(
        -confirm-license -opensource
        -release
        -prefix "$QT_INSTALL_ROOT"
        -nomake tests -nomake examples
        -force-debug-info -separate-debug-info
        -no-sql-mysql -sql-sqlite
        -qt-libjpeg
        -qt-libpng
        -qt-pcre
        -qt-harfbuzz
        -openssl-runtime
    )
    local cmake_args=(${COMMON_CMAKE_ARGS[@]+"${COMMON_CMAKE_ARGS[@]}"} "-DOPENSSL_ROOT_DIR=$DEPS_PREFIX/openssl")

    case "$PLATFORM" in
        linux)
            args+=(
                -platform linux-clang
                -no-libudev
                -sql-psql
                -xcb
                -bundled-xcb-xinput
                -system-freetype
                -fontconfig
                -icu
                -sysconfdir /etc/xdg
            )
            cmake_args+=(
                "-DICU_ROOT=$DEPS_PREFIX/icu"
                # Link libGL rather than libOpenGL + libGLX, like Qt's own
                # Linux binaries (coin/platform_configs, RHEL packaging).
                -DOpenGL_GL_PREFERENCE=LEGACY
            )
            ;;
        macos)
            args+=(
                -platform macx-clang
                -no-sql-psql
                -no-xcb
                -no-pkg-config
                -sysconfdir /Library/Preferences/Qt
            )
            cmake_args+=("-DCMAKE_OSX_ARCHITECTURES=$MACOS_ARCHS")
            if [ -n "${MACOS_DEPLOYMENT_TARGET:-}" ]; then
                cmake_args+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_DEPLOYMENT_TARGET")
            fi
            ;;
    esac

    show_exec "$src/configure" "${args[@]}" -- "${cmake_args[@]}"
}

configure_module() {
    local module="$1" src="$2"
    local cmake_args=(${COMMON_CMAKE_ARGS[@]+"${COMMON_CMAKE_ARGS[@]}"})
    case "$module" in
        qtimageformats)
            # Use the bundled libtiff/libwebp instead of whatever the host has
            # (as Qt's own packaging does).
            cmake_args+=(-DINPUT_tiff=qt -DINPUT_webp=qt)
            ;;
    esac
    show_exec "$QT_INSTALL_ROOT/bin/qt-configure-module" "$src" -- ${cmake_args[@]+"${cmake_args[@]}"}
}

if [ "$PLATFORM" = linux ] && [ -d "$DEPS_PREFIX/icu/lib" ]; then
    # Qt's tools (moc, rcc, ...) link ICU; make it findable while building.
    export LD_LIBRARY_PATH="$DEPS_PREFIX/icu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

for module in "${modules[@]}"; do
    if [ -n "$RESUME" ] && [ -f "$BUILD_INFO_DIR/$module.done" ]; then
        log "$module is already installed, skipping"
        if [ "$module" = "$UNTIL" ]; then break; fi
        continue
    fi
    log "Building $module $QT_VERSION ($PLATFORM $ARCH, $JOBS jobs)"
    if [ "$module" != qtbase ] && [ ! -x "$QT_INSTALL_ROOT/bin/qt-configure-module" ]; then
        die "qtbase is not installed in $QT_INSTALL_ROOT; build it first"
    fi

    src="$(extract_clean "$(fetch_verified "$(qt_source_file "$module")" "$(qt_source_url "$module")")" "$BUILD_DIR/src-$module")"
    apply_patches "$module" "$src"

    bld="$BUILD_DIR/$module"
    rm -rf "$bld"
    mkdir -p "$bld"
    pushd "$bld" >/dev/null

    if [ "$module" = qtbase ]; then
        if [ "$PLATFORM" = linux ]; then
            # Bundle ICU with Qt (pia-foss passes it as --extra-install).  It
            # goes in first so the installed Qt tools can always find it
            # through their $ORIGIN/../lib RPATH.
            mkdir -p "$QT_INSTALL_ROOT"
            cp -a "$DEPS_PREFIX/icu/." "$QT_INSTALL_ROOT/"
        fi
        configure_qtbase "$src"
    else
        configure_module "$module" "$src"
    fi

    show_exec cmake --build . --parallel "$JOBS"
    show_exec cmake --install .

    # Keep the configure summary with the installation, for reference.
    mkdir -p "$BUILD_INFO_DIR"
    if [ -f config.summary ]; then
        cp config.summary "$BUILD_INFO_DIR/$module.config.summary"
    fi
    touch "$BUILD_INFO_DIR/$module.done"

    popd >/dev/null
    # Free disk space as we go, CI runners don't have much.
    rm -rf "$bld" "$BUILD_DIR/src-$module"

    if [ "$module" = "$UNTIL" ]; then break; fi
done
log "Done: Qt installed in $QT_INSTALL_ROOT"
