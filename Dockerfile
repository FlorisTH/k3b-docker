##############################################################################
# Stage 1: build k3b from source with the FFmpeg decoder plugin enabled.
#
# Alpine's own k3b package (v23.08.4-r0, see community/k3b/APKBUILD on the
# 3.19-stable aports branch) is built WITHOUT ffmpeg-dev in makedepends, so
# find_package(FFmpeg) fails at build time and plugins/decoder/ffmpeg/
# (k3bffmpegdecoder) never gets compiled in. That plugin is k3b's only code
# path for AAC/M4A - none of the other decoder plugins (mp3/ogg/flac/wave/
# musepack) touch that codec. Rebuilding with ffmpeg-dev present is the fix.
#
# This is the *exact* same recipe Alpine uses for this version (same
# source tarball, same cmake flags, same makedepends list), with ffmpeg-dev
# added. Everything below is pinned to what's actually running in the
# container today (checked via `apk info k3b` -> k3b-23.08.4-r0, KF5/Qt5).
##############################################################################
FROM alpine:3.19 AS builder

RUN apk add --no-cache \
        build-base \
        cmake \
        samurai \
        extra-cmake-modules \
        flac-dev \
        karchive5-dev \
        kcmutils5-dev \
        kconfig5-dev \
        kcoreaddons5-dev \
        kdoctools5-dev \
        kfilemetadata5-dev \
        ki18n5-dev \
        kiconthemes5-dev \
        kio5-dev \
        kjobwidgets5-dev \
        knewstuff5-dev \
        knotifications5-dev \
        knotifyconfig5-dev \
        kservice5-dev \
        kwidgetsaddons5-dev \
        kxmlgui5-dev \
        lame-dev \
        libdvdread-dev \
        libkcddb-dev \
        libmad-dev \
        libsamplerate-dev \
        libvorbis-dev \
        qt5-qtbase-dev \
        shared-mime-info \
        solid5-dev \
        taglib-dev \
        ffmpeg-dev \
        curl \
        tar

ARG K3B_VERSION=23.08.4
WORKDIR /src

RUN curl -fsSL "https://download.kde.org/stable/release-service/${K3B_VERSION}/src/k3b-${K3B_VERSION}.tar.xz" \
        -o k3b.tar.xz \
    && tar xf k3b.tar.xz \
    && rm k3b.tar.xz

WORKDIR /src/k3b-23.08.4

# Same cmake flags Alpine's APKBUILD uses, minus nothing - we WANT the
# FFmpeg plugin, which is ON by default and just needs FFMPEG_FOUND=true.
RUN cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DK3B_BUILD_MUSE_DECODER_PLUGIN=OFF \
        -DK3B_BUILD_SNDFILE_DECODER_PLUGIN=OFF \
        -DK3B_ENABLE_MUSICBRAINZ=OFF \
    && cmake --build build

# Fail the build loudly here (not silently later at runtime) if FFmpeg
# detection didn't actually work, so a broken image is never produced.
# NOTE: k3b's build collects all plugin .so files into build/bin/k3b_plugins/
# (not the plugins/decoder/ffmpeg/ source subdirectory) - confirmed via the
# "Linking CXX shared module bin/k3b_plugins/k3bffmpegdecoder.so" line in
# ninja's output.
RUN test -f build/bin/k3b_plugins/k3bffmpegdecoder.so \
    || (echo "!! k3bffmpegdecoder.so was not built - FFmpeg was not detected !!" && exit 1)

RUN DESTDIR=/out cmake --install build

##############################################################################
# Stage 2: the actual runtime image (unchanged from the working setup),
# with our freshly-built k3b copied in instead of `add-pkg k3b`.
##############################################################################
FROM jlesage/baseimage-gui:alpine-3.19-v4

RUN \
    add-pkg \
        cdrdao \
        cdrkit \
        dvd+rw-tools \
        libburn \
        dbus \
        udisks2 \
        eudev \
        lsscsi \
        font-noto \
        fontconfig \
        # Runtime libs for our self-built k3b. Installed as the -dev
        # packages (which pull in their runtime .so counterparts as
        # dependencies) rather than hand-picked runtime-only package
        # names, to avoid missing one and getting a silent symbol error
        # at startup. Can be slimmed down later once confirmed working.
        flac-dev \
        karchive5-dev \
        kcmutils5-dev \
        kconfig5-dev \
        kcoreaddons5-dev \
        kdoctools5-dev \
        kfilemetadata5-dev \
        ki18n5-dev \
        kiconthemes5-dev \
        kio5-dev \
        kjobwidgets5-dev \
        knewstuff5-dev \
        knotifications5-dev \
        knotifyconfig5-dev \
        kservice5-dev \
        kwidgetsaddons5-dev \
        kxmlgui5-dev \
        lame-dev \
        libdvdread-dev \
        libkcddb-dev \
        libmad-dev \
        libsamplerate-dev \
        libvorbis-dev \
        qt5-qtbase-dev \
        shared-mime-info \
        solid5-dev \
        taglib-dev \
        ffmpeg-dev

# Copy our self-built k3b (with the FFmpeg/AAC/M4A decoder plugin) in place
# of the apk package.
COPY --from=builder /out/usr/ /usr/

# Generate and install favicons.
RUN \
    APP_ICON_URL=https://github.com/jlesage/docker-templates/raw/master/jlesage/images/k3b-icon.png && \
    install_app_icon.sh "$APP_ICON_URL" || true

# Remove the <user>messagebus</user> directive from dbus's system config.
# dbus-daemon --system normally starts as root and drops privileges to the
# messagebus user; in this container dbus-daemon already runs unprivileged
# (as the app user), so it can't switch users. Without this, dbus fails with
# "Failed to drop supplementary groups: Operation not permitted".
RUN sed -i '/<user>messagebus<\/user>/d' /usr/share/dbus-1/system.conf

# Add files.
COPY rootfs/ /

RUN chmod +x /etc/cont-init.d/*.sh

# Make sure all our added scripts are executable.
RUN chmod +x \
    /etc/cont-init.d/12-dbus-dir.sh \
    /etc/cont-init.d/13-dbus-user.sh \
    /etc/services.d/app/run \
    /etc/services.d/dbus/run \
    /etc/services.d/dbus/is_ready \
    /etc/services.d/udisksd/run \
    /etc/services.d/udisksd/is_ready \
    /etc/services.d/udevd/run \
    /etc/services.d/udevd/is_ready \
    /etc/services.d/udev-trigger/run

# NOTE: rootfs/etc/dbus-1/system.d/k3b-udisks2.conf (copied in above via
# COPY rootfs/ /) grants the unprivileged app user permission to own the
# org.freedesktop.UDisks2 bus name. D-Bus policy files are additive, so
# this works alongside the package's own root-only policy without needing
# to edit or remove it.

# Define the application's ports.
EXPOSE 5800
EXPOSE 5900

# Metadata.
ARG DOCKER_IMAGE_VERSION
ENV APP_NAME="K3b"
LABEL \
      org.label-schema.name="k3b-docker" \
      org.label-schema.description="Docker container for K3b (with FFmpeg/AAC/M4A decoder support)" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.schema-version="1.0"