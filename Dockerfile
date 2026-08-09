# Custom K3b container, built on jlesage's baseimage-gui instead of a
# general-purpose webtop image. This gets us:
#   - The same web GUI / VNC plumbing that ImgBurn and Xfburn use
#   - Proper s6-style supervised services with readiness checks, so we can
#     make udisksd wait for a REAL dbus connection instead of guessing with
#     sleep loops, and make K3b wait for udisksd to actually register
#     org.freedesktop.UDisks2 before it ever launches.
#
# Check for a newer tag at https://hub.docker.com/r/jlesage/baseimage-gui/tags
FROM jlesage/baseimage-gui:alpine-3.19-v4

# K3b + burning backends + the D-Bus/udisks stack K3b needs for automatic
# drive discovery (K3b >= ~24.x has no manual "Add Device" fallback anymore).
RUN add-pkg \
        k3b \
        cdrdao \
        cdrkit \
        dvd+rw-tools \
        dbus \
        udisks2 \
        eudev

# Service definitions (dbus + udisksd) and app init.
COPY rootfs/ /
RUN chmod +x \
        /etc/services.d/dbus/run \
        /etc/services.d/dbus/is_ready \
        /etc/services.d/udisksd/run \
        /etc/services.d/udisksd/is_ready \
        /etc/cont-init.d/12-dbus-dir.sh \
        /etc/cont-init.d/13-dbus-user.sh

# Start script that finally launches K3b itself.
COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# App metadata shown in the web UI.
RUN set-cont-env APP_NAME "K3b"

# Persisted K3b config/state.
VOLUME ["/config"]
