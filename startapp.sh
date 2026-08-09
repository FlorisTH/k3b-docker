#!/bin/sh
# This is the baseimage's actual "app" process - the supervisor manages it
# like any other service, so unlike a cont-init.d script, nothing can reap
# it out from under a background job. We still double-check udisksd is
# actually answering before exec-ing K3b, belt-and-braces, since a stale
# container restart could in theory race this too.

for i in $(seq 1 60); do
    dbus-send --system --print-reply \
        --dest=org.freedesktop.UDisks2 /org/freedesktop/UDisks2 \
        org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1 && break
    sleep 0.5
done

exec /usr/bin/k3b
