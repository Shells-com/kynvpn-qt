# Linux build environment for Qt.
#
# AlmaLinux 9 matches the RHEL 9 environment Qt uses for its own official Linux
# binaries (qt5.git coin/platform_configs/cmake_platforms.yaml, "Packaging"),
# so the result runs on anything with glibc >= 2.34 (RHEL/Alma/Rocky 9+,
# Debian 12+, Ubuntu 22.04+, Fedora 35+).
#
# pia-foss built in a Debian Stretch/Bullseye chroot for Qt 5.15 / 6.2; that's
# too old for Qt 6.12 (OpenSSL 1.1, glibc below Qt's baseline).
FROM almalinux:9

# Mirrors can lag right after an AlmaLinux point release: retry downloads and
# always refresh the metadata.
RUN echo -e 'retries=10\nskip_if_unavailable=False' >> /etc/dnf/dnf.conf \
 && dnf -y --refresh install dnf-plugins-core epel-release \
 && dnf config-manager --set-enabled crb \
 && dnf -y --refresh install \
      clang gcc-c++ make patch perl python3 python3-pip \
      git xz file which findutils tar gzip diffutils \
      fontconfig-devel freetype-devel glib2-devel dbus-devel at-spi2-core-devel \
      zlib-devel libpq-devel \
      libxkbcommon-devel libxkbcommon-x11-devel \
      libX11-devel libXext-devel libXrender-devel libXi-devel libSM-devel libICE-devel \
      libxcb-devel xcb-util-devel xcb-util-image-devel xcb-util-keysyms-devel \
      xcb-util-renderutil-devel xcb-util-wm-devel xcb-util-cursor-devel \
      libglvnd-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel libdrm-devel \
      wayland-devel wayland-protocols-devel \
 && dnf clean all

COPY requirements-build.txt /tmp/requirements-build.txt
RUN python3 -m venv /opt/buildtools \
 && /opt/buildtools/bin/pip install --no-cache-dir -r /tmp/requirements-build.txt
ENV PATH=/opt/buildtools/bin:$PATH
