# kynvpn-qt

Open source Qt builds for the KynVPN desktop client (a fork of the
[PIA desktop client](https://github.com/pia-foss/desktop)).

This repository replaces the Qt part of
[pia-foss/desktop-dep-build](https://github.com/pia-foss/desktop-dep-build).
It produces the same kind of package (a self-extracting `.run` installer with
headers, libraries, tools and debug symbols, laid out like the official Qt
installers), but it builds the current Qt release, and the whole build runs on
GitHub Actions from pinned, hash-verified upstream source archives.

## Releases

Push a tag named `v<qt version>-<revision>`, e.g. `v6.12.0-1`, and
[`build.yml`](.github/workflows/build.yml) builds every platform and publishes
a GitHub release with these files:

| Package | Platform |
|---|---|
| `qt-<ver>-kynvpn-linux-x86_64.run` | Linux x86_64, glibc ≥ 2.34 |
| `qt-<ver>-kynvpn-linux-arm64.run` | Linux arm64, glibc ≥ 2.34 |
| `qt-<ver>-kynvpn-macos-universal.run` | macOS universal (arm64 + x86_64) |
| `SHA256SUMS` | |

The release workflow also attaches GitHub build provenance attestations, so
you can check that a package was built by this repository's workflow:

```sh
gh attestation verify qt-6.12.0-kynvpn-linux-x86_64.run --repo Shells-com/kynvpn-qt
```

The tag must match `QT_VERSION` in `config.sh`. A manual run (Actions → Build
Qt → Run workflow) builds everything and keeps the packages as workflow
artifacts, without making a release.

A full build takes several hours. Each platform's build is split into four
sequential jobs (see [`build-platform.yml`](.github/workflows/build-platform.yml))
so no job gets near the 6 hour limit of GitHub-hosted runners.

## Installing

```sh
./qt-6.12.0-kynvpn-linux-x86_64.run                         # interactive
./qt-6.12.0-kynvpn-linux-x86_64.run -- /opt/Qt6.12.0 --yes  # non-interactive (CI)
```

Qt ends up in `<dir>/<version>/<build>`, e.g.
`~/Qt6.12.0-kynvpn/6.12.0/clang_64` (`clang_arm64` on arm64,
`clang_universal` on macOS). This is the layout the client's
`rake/model/qt.rb` looks for under `$HOME/Qt*/6.*` and `/opt/Qt*/6.*`. Set
`QTROOT=<dir>/<version>` to pick it explicitly. The installation contains
`share/pia-qt-build` so the client's Qt detection prefers it, just like the
PIA builds.

`share/qt-build-info/` in the installation records how it was built: versions,
pinned source hashes, each module's configure summary, and the workflow run.

## What gets built

Versions are set in [`config.sh`](config.sh). Source hashes are pinned in
[`sources.sha256`](sources.sha256).

- **Qt** modules: qtbase, qtshadertools, qtsvg, qtimageformats, qtdeclarative,
  qtwayland (Linux), qt5compat, qttools, qttranslations. That covers
  everything the client uses (Core, Gui, Widgets, Network, DBus, Qml, Quick,
  QuickControls2, Shapes, Layouts, `Qt.labs.platform`, the XCB/Wayland/Cocoa
  platform plugins, the TLS plugins) and the tools it calls (moc, rcc,
  lupdate, lrelease, macdeployqt). Add modules to `QT_MODULES` if you need
  more.
- **ICU** (Linux): built from source and bundled into `<qt>/lib`, like PIA
  does. The client deploys `libicu*.so.*` from there.
- **patchelf** (Linux): shipped in `<qt>/bin`, the client uses it to deploy
  on Linux.
- **OpenSSL** headers: Qt is configured with `-openssl-runtime`, so it loads
  `libssl.so.3` / `libssl.3.dylib` at runtime. The client ships OpenSSL
  itself. No OpenSSL binaries go into the package.

### Build environments

| Platform | Runner | Environment |
|---|---|---|
| Linux x86_64 | `ubuntu-24.04` | AlmaLinux 9 container, clang ([Dockerfile](docker/linux-builder.Dockerfile)) |
| Linux arm64 | `ubuntu-24.04-arm` | same container, native arm64 |
| macOS | `macos-15` | Xcode / Apple clang, universal build in one pass (`CMAKE_OSX_ARCHITECTURES="arm64;x86_64"`) |

CMake and Ninja are installed from PyPI at the versions in
[`requirements-build.txt`](requirements-build.txt), the same CMake version
Qt's own CI uses for this release.

**Why AlmaLinux 9 and not Debian.** PIA built Qt 5.15 / 6.2 in a Debian
Stretch / Bullseye chroot. Qt 6.12 needs a newer toolchain and OpenSSL 3, and
Qt's own Linux binaries for 6.12 are built on RHEL 9. AlmaLinux 9 is the open
source equivalent, so the packages run on anything with glibc 2.34 or newer
(RHEL/Alma/Rocky 9+, Debian 12+, Ubuntu 22.04+, Fedora 35+). **The client
must be built on a distribution at least that new too.** Its Debian 11 build
container is too old to link against these libraries.

**macOS minimum version.** Qt 6.12 itself requires macOS 14.4 or newer
(`QT_SUPPORTED_MIN_MACOS_VERSION` in qtbase), and needs Xcode 16 / the macOS
15 SDK or newer to build.

### Configure options

The options follow PIA's `components/qt/build-linux.sh`, translated from Qt
5.15 to Qt 6:

| PIA (Qt 5.15) | Here (Qt 6) | Notes |
|---|---|---|
| `-confirm-license -opensource -release` | same | |
| `-nomake tests -nomake examples` | same | |
| `-force-debug-info -separate-debug-info` | same | Debug symbols are shipped in the package (`.debug` files / `.dSYM` bundles), as before |
| `-qt-libjpeg -qt-libpng -qt-pcre -qt-harfbuzz` | same | |
| `-no-sql-mysql -plugin-sql-sqlite` | `-no-sql-mysql -sql-sqlite` | Qt 6 syntax |
| `-plugin-sql-psql` (Linux) / `-no-sql-psql` (macOS) | `-sql-psql` / `-no-sql-psql` | |
| `-openssl` + their own OpenSSL 1.1 | `-openssl-runtime` + OpenSSL 3 headers | Qt 6.5+ needs OpenSSL 3 |
| Linux: `-xcb -bundled-xcb-xinput -system-freetype -fontconfig -icu -no-libudev -sysconfdir /etc/xdg -platform linux-clang` | same | |
| Linux: their own libxcb build | system libxcb from AlmaLinux 9 | Only needed for Debian Stretch. The client ships its own xcb libraries anyway |
| macOS: `-no-xcb -sysconfdir /Library/Preferences/Qt -platform macx-clang` | same | |
| macOS: `QMAKE_APPLE_DEVICE_ARCHS=<arch>`, then two builds merged with lipo | `CMAKE_OSX_ARCHITECTURES="arm64;x86_64"` | Qt 6 builds universal binaries directly |
| `-skip doc,webchannel,webengine,webview,sensors,serialport` | build only the modules listed in `config.sh` | |
| `-R .` | dropped | Would add `.` (the current directory) to the RPATH. Qt 6 uses `$ORIGIN`-relative RPATHs by default |
| `QMAKE_LFLAGS_APP+=-s` | dropped | qmake-only. `-separate-debug-info` strips the binaries |
| `-no-use-gold-linker` | dropped | Qt 6 doesn't use gold by default |

Additions:

- Linux: `-DOpenGL_GL_PREFERENCE=LEGACY` (link `libGL` like Qt's official
  binaries do).
- qtimageformats: bundled libtiff/libwebp (`-DINPUT_tiff=qt -DINPUT_webp=qt`),
  as in Qt's packaging.
- macOS: `-no-pkg-config` and `CMAKE_IGNORE_PREFIX_PATH=/opt/homebrew;/usr/local`.
  GitHub's macOS images come with many Homebrew packages, and PIA's notes warn
  that Qt picks such packages up. With these options the macOS build depends
  only on the SDK.

PIA's two Qt 5.15 source patches don't apply to Qt 6, see
[`patches/README.md`](patches/README.md).

## Updating Qt

```sh
scripts/update-qt.sh 6.12.1     # bumps QT_VERSION and pins the new module hashes
git commit -am "Qt 6.12.1"
git tag v6.12.1-1 && git push origin master v6.12.1-1
```

ICU, OpenSSL and patchelf are bumped by hand: change the version in
`config.sh` and the hash in `sources.sha256`.

## Building outside GitHub Actions

The scripts also work on a regular machine (Linux: run them inside the
container from `docker/linux-builder.Dockerfile`). Plan for a lot of CPU time
and about 40 GB of disk.

```sh
scripts/fetch-sources.sh   # download and verify everything into out/cache
scripts/build-deps.sh      # ICU, patchelf (Linux), OpenSSL headers
scripts/build-qt.sh        # all modules -> out/install/<ver>/<build>
scripts/finalize.sh        # patchelf, marker files, build info
scripts/package.sh         # out/artifacts/qt-<ver>-kynvpn-<platform>-<arch>.run
```

`build-qt.sh --resume --until <module>` builds part of the module list (CI
uses this to split the work). `JOBS=<n>` overrides the parallelism, and
`MACOS_ARCHS=arm64` gives a single-architecture macOS build.

## License

The build scripts are GPLv3, derived in part from pia-foss/desktop-dep-build.
See [LICENSE.txt](LICENSE.txt). The packages contain Qt under its open source
licenses (LGPLv3/GPL), ICU (Unicode License) and patchelf (GPLv3).
