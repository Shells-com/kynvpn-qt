#!/usr/bin/env bash
# Package the Qt installation as a self-extracting installer:
#   out/artifacts/qt-<version>-<dist>-<platform>-<arch>.run
#
# Adapted from pia-foss/desktop-dep-build components/qt/make-installer-package.sh
# (Copyright (c) 2022 Private Internet Access, Inc., GPLv3).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ -d "$QT_INSTALL_ROOT" ] || die "No Qt installation in $QT_INSTALL_ROOT"

PKG_BUILD="$WORK/package"
ARCHIVE_NAME="$PACKAGE_BASENAME.tar.xz"
INSTALLER="$ARTIFACTS_DIR/$PACKAGE_BASENAME.run"

rm -rf "$PKG_BUILD"
mkdir -p "$PKG_BUILD" "$ARTIFACTS_DIR"
rm -f "$INSTALLER"

log "Creating $ARCHIVE_NAME"
# makeself uses GNU tar when it can find one (e.g. Homebrew's gtar on macOS),
# so pick the same tar here and use the owner options that tar understands.
TAR="$(command -v gtar || command -v tar)"
if "$TAR" --version 2>/dev/null | grep -q "GNU tar"; then
    TAR_OWNER=(--owner=0 --group=0 --numeric-owner --sort=name)
else
    TAR_OWNER=(--uid 0 --gid 0 --numeric-owner)
fi
(cd "$QT_INSTALL_ROOT" && "$TAR" "${TAR_OWNER[@]}" -cf - .) | xz -T0 -6 > "$PKG_BUILD/$ARCHIVE_NAME"

subst() {
    sed -e "s/{{QT_VERSION}}/$QT_VERSION/g" \
        -e "s/{{QT_ARCHIVE}}/$ARCHIVE_NAME/g" \
        -e "s/{{QT_BUILD_NAME}}/$QT_BUILD_NAME/g" \
        -e "s/{{DIST_NAME}}/$DIST_NAME/g" "$1" > "$2"
    chmod a+x "$2"
}
subst "$ROOT/packaging/install.sh" "$PKG_BUILD/install.sh"
subst "$ROOT/packaging/extract.sh" "$PKG_BUILD/extract.sh"

log "Creating $INSTALLER"
# The payload is already compressed, so the makeself archive isn't.
"$ROOT/third_party/makeself/makeself.sh" --nox11 --nocomp --sha256 --tar-quietly --keep-umask \
    --tar-extra "${TAR_OWNER[*]}" \
    "$PKG_BUILD" "$INSTALLER" "Qt $QT_VERSION - $DIST_NAME ($PLATFORM $ARCH)" ./install.sh

rm -rf "$PKG_BUILD"
(cd "$ARTIFACTS_DIR" && sha256_compat "$(basename "$INSTALLER")" > "$(basename "$INSTALLER").sha256")
ls -l "$ARTIFACTS_DIR"
