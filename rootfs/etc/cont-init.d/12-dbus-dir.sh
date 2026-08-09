#!/bin/sh
mkdir -p /run/dbus
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /run/dbus

mkdir -p /run/udisks2
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /run/udisks2

mkdir -p /var/lib/udisks2
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /var/lib/udisks2
