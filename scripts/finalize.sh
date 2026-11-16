#!/usr/bin/env bash
# Final touches on the Qt installation after all modules are built:
# extra tools, marker files and build provenance.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ -x "$QT_INSTALL_ROOT/bin/qmake" ] || [ -x "$QT_INSTALL_ROOT/bin/qmake6" ] || \
    die "No Qt installation in $QT_INSTALL_ROOT"

if [ "$PLATFORM" = linux ]; then
    # The client uses <qt>/bin/patchelf for Linux deployment when present.
    cp "$DEPS_PREFIX/patchelf/bin/patchelf" "$QT_INSTALL_ROOT/bin/"
fi

# The client's Qt detection (rake/model/qt.rb) prefers builds containing this
# marker; keep the upstream name so it works unmodified.
mkdir -p "$QT_INSTALL_ROOT/share/qt-build-info"
touch "$QT_INSTALL_ROOT/share/pia-qt-build"
touch "$QT_INSTALL_ROOT/share/$DIST_NAME-qt-build"

info="$QT_INSTALL_ROOT/share/qt-build-info"
cp "$ROOT/sources.sha256" "$ROOT/config.sh" "$ROOT/LICENSE.txt" "$info/"
{
    echo "Qt $QT_VERSION ($DIST_NAME build)"
    echo "platform: $PLATFORM"
    echo "arch: $ARCH"
    echo "build name: $QT_BUILD_NAME"
    echo "modules: $(qt_modules_for_platform | tr '\n' ' ')"
    if [ "$PLATFORM" = linux ]; then
        echo "icu: $ICU_VERSION"
        echo "patchelf: $PATCHELF_VERSION"
        echo "glibc: $(ldd --version | head -n 1)"
    else
        echo "sdk: $(xcrun --show-sdk-version 2>/dev/null || echo unknown)"
    fi
    echo "openssl headers: $OPENSSL_VERSION (loaded at runtime, not bundled)"
    echo "compiler: $(${CXX:-clang++} --version | head -n 1)"
    echo "source commit: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    if [ -n "${GITHUB_RUN_ID:-}" ]; then
        echo "built by: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
    fi
    echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$info/BUILD-INFO.txt"
cat "$info/BUILD-INFO.txt"
