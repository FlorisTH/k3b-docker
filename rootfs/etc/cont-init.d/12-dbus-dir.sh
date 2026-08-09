#!/bin/sh
#
# Creates /run/dbus with correct ownership before the dbus service starts.
#
# Numbered 12 so it runs AFTER 09-var-dirs.sh (the baseimage's own script
# that resets /run's layout on every boot) - if this ran earlier, var-dirs
# would wipe the directory right back out and dbus would fail with
# "mkdir: can't create directory '/run/dbus': Permission denied".

mkdir -p /run/dbus
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /run/dbus

mkdir -p /run/udisks2
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /run/udisks2

mkdir -p /var/lib/udisks2
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /var/lib/udisks2
