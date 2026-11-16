# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are used by the scripts sourcing this file
# Versions of everything this repository builds.  Sourced by scripts/*.sh.
#
# To move to a new Qt release, run scripts/update-qt.sh <version>; it updates
# QT_VERSION below and the Qt hashes in sources.sha256.  Other dependencies are
# bumped by hand (update the version here and the hash in sources.sha256).

QT_VERSION=6.12.0

# Qt modules (repositories) to build, in dependency order.  A ":linux" or
# ":macos" suffix restricts a module to one platform.
#
# This is a curated subset of qt-everywhere: everything the desktop client
# uses (Core, Gui, Widgets, Network, DBus, Qml, Quick, QuickControls2,
# QuickShapes, QuickLayouts, Qt.labs.platform, Wayland/XCB platform plugins,
# TLS plugins) plus the build tools it calls (moc, rcc, lupdate, lrelease,
# macdeployqt) and a few modules that are commonly needed when porting.
QT_MODULES=(
    qtbase
    qtshadertools
    qtsvg
    qtimageformats
    qtdeclarative
    qtwayland:linux
    qt5compat
    qttools
    qttranslations
)

# ICU is built from source and bundled with Qt on Linux (the client deploys
# libicu*.so.* from the Qt lib directory).  Not used on macOS.
ICU_VERSION=79.1

# OpenSSL headers are needed to build Qt's OpenSSL TLS backend.  Qt is
# configured with -openssl-runtime, so it dlopen()s libssl.so.3 /
# libssl.3.dylib at runtime and no OpenSSL binaries are bundled.  Keep this on
# the same major version the client ships.
OPENSSL_VERSION=3.5.9

# patchelf is built and shipped in <qt>/bin, the client uses it for
# deployment on Linux.
PATCHELF_VERSION=0.19.3

# Suffix used in package names and the default installation directory.
DIST_NAME=kynvpn
