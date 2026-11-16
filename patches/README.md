# Source patches

Patches in `patches/<component>/*.patch` are applied (with `patch -p1`, in
file name order) after extracting that component's source archive.
`<component>` is a Qt repository name (`qtbase`, `qtdeclarative`, ...) or one
of `icu`, `openssl`, `patchelf`.

There are currently no patches. The two Qt patches carried by
pia-foss/desktop-dep-build for Qt 5.15.2 are not needed for Qt 6:

- `0001-Fix-missing-macos-inclusion.patch` (missing `CGColorSpace.h` include in
  the cocoa plugin) is fixed upstream.
- `0002-Fix-macos-stat64.patch` touches qt3d's bundled assimp, and qt3d is not
  built here.

The ICU patch they carry (`Don't link libicudata as data-only library`) only
matters for armhf, which is not built here.
