#!/bin/sh
mkdir -p /run/dbus
chown "${USER_ID:-1000}:${GROUP_ID:-1000}" /run/dbus
