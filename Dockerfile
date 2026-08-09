# Pull base image.
FROM jlesage/baseimage-gui:alpine-3.19-v4

# Install K3b and its burning backends, plus D-Bus (needed only for the
# desktop/GUI session itself, NOT for optical drive detection).
#
# NOTE: udisks2 and eudev are intentionally NOT installed. K3b's automatic
# drive detection goes through Solid -> UDisks2, which requires a working
# D-Bus system bus with a root-owned dbus-daemon (something this container
# can't provide, since everything runs unprivileged). Instead, the drive is
# added manually in K3b (Settings > Setup Devices > Add Device -> /dev/sr0),
# and the actual burn is handed directly to cdrdao/wodim/growisofs against
# the device node - no UDisks2 involved. See README.md for details.
RUN \
    add-pkg \
        k3b \
        cdrdao \
        cdrkit \
        dvd+rw-tools \
        dbus \
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
    /etc/services.d/app/run

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
