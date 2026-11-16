#! /usr/bin/env bash

# Copyright (c) 2022 Private Internet Access, Inc.
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

# Called by install.sh, either as the regular user if the directory is
# writable, or with 'sudo' otherwise.

set -e

INSTALL_DIR="$1"
[ -n "$INSTALL_DIR" ] || { echo "usage: $0 <dir>" >&2; exit 1; }

mkdir -p "$INSTALL_DIR"
touch "$INSTALL_DIR/install-write-test"
rm -rf "${INSTALL_DIR:?}"/*

tar -xf "{{QT_ARCHIVE}}" --xz -C "$INSTALL_DIR"
