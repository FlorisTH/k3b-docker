#!/bin/sh
#
# Recreates the 'messagebus' system user/group if missing.
#
# dbus-daemon --system looks up the messagebus UID/GID even when it isn't
# switching to it (see the system.conf sed in the Dockerfile). The Alpine
# dbus package creates this account at build time, but 10-init-users.sh
# rewrites /etc/passwd and /etc/group at every container start based on
# USER_ID/GROUP_ID, which wipes it out. Runs after 10-init-users.sh so it
# re-adds the account every boot.
#
# Safe to run every boot: the getent checks make it a no-op if the account
# already exists.

getent group messagebus >/dev/null 2>&1 || addgroup -S messagebus
getent passwd messagebus >/dev/null 2>&1 || adduser -S -D -H -G messagebus -s /sbin/nologin messagebus
