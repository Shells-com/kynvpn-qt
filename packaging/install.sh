#! /usr/bin/env bash

# Copyright (c) 2022 Private Internet Access, Inc.
# Modified for the {{DIST_NAME}} Qt distribution: optional non-interactive
# usage.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.

# Usage (through the .run package):
#   ./qt-<...>.run                              interactive
#   ./qt-<...>.run -- <install_dir> [--yes]     non-interactive
#
# Qt is installed to <install_dir>/{{QT_VERSION}}/{{QT_BUILD_NAME}}, the same
# layout as the official Qt installers.

set -e

DEFAULT_INSTALL_DIR="$HOME/Qt{{QT_VERSION}}-{{DIST_NAME}}"
INSTALL_DIR=""
ASSUME_YES=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help)
            echo "usage: $0 [<install_dir>] [--yes]"
            echo "Installs Qt {{QT_VERSION}} to <install_dir>/{{QT_VERSION}}/{{QT_BUILD_NAME}}"
            echo "(default <install_dir>: $DEFAULT_INSTALL_DIR)"
            exit 0
            ;;
        *) INSTALL_DIR="$arg" ;;
    esac
done

echo "Qt {{QT_VERSION}} - {{DIST_NAME}} build ({{QT_BUILD_NAME}})"
if [ -z "$INSTALL_DIR" ]; then
    if [ -z "$ASSUME_YES" ] && [ -t 0 ]; then
        read -rp "Installation directory: [$DEFAULT_INSTALL_DIR]: " INSTALL_DIR
    fi
    INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
fi

# Extract to the specific version/build directory, so builds for several
# architectures can be installed side by side, e.g.
# /home/user/Qt6.12.0-kynvpn/6.12.0/clang_64
QT_BUILD_DIR="$INSTALL_DIR/{{QT_VERSION}}/{{QT_BUILD_NAME}}"

if [ -d "$QT_BUILD_DIR" ] && [ -z "$ASSUME_YES" ]; then
    echo "WARNING: Directory $QT_BUILD_DIR exists, existing contents will be deleted."
    DELETE_EXISTING=""
    [ -t 0 ] && read -rp "Continue? [y/N]: " DELETE_EXISTING
    if ! [[ $DELETE_EXISTING =~ ^[yY]$ ]]; then
        echo "Canceled (pass --yes to overwrite)."
        exit 1
    fi
fi

if mkdir -p "$QT_BUILD_DIR" 2>/dev/null && touch "$QT_BUILD_DIR/install-write-test" 2>/dev/null; then
    ./extract.sh "$QT_BUILD_DIR"
else
    echo "Using sudo to install to $QT_BUILD_DIR"
    sudo ./extract.sh "$QT_BUILD_DIR"
fi

echo "Installed to $QT_BUILD_DIR"
