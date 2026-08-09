# Pull base image.
FROM jlesage/baseimage-gui:alpine-3.19-v4

# Install K3b, its burning backends, and the D-Bus/udisks2/udev stack it
# needs for drive detection.
#
# NOTE: modern (KF5-based) K3b has no manual "add device" fallback - it
# relies entirely on Solid -> UDisks2 to discover optical drives. UDisks2
# in turn needs udev to have tagged the device (ID_CDROM=1 etc.) via a
# live kernel event, which is why eudev is installed too - see the
# udevd/udev-trigger services under rootfs/etc/services.d/.
RUN \
    add-pkg \
        k3b \
        cdrdao \
        cdrkit \
        dvd+rw-tools \
        dbus \
        udisks2 \
        eudev \
        lsscsi \
        font-noto \
        fontconfig

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
      org.label-schema.description="Docker container for K3b" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.schema-version="1.0"
