#!/bin/sh
getent group messagebus >/dev/null 2>&1 || addgroup -S messagebus
getent passwd messagebus >/dev/null 2>&1 || adduser -S -D -H -G messagebus -s /sbin/nologin messagebus
