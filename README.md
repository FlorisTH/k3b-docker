# k3b-docker

K3b running in a `jlesage/baseimage-gui` container, accessed via a web browser
on port 5800.

## Why there's no UDisks2 / udev in this image

K3b's *automatic* drive detection goes through KDE's Solid framework, which
needs a fully working D-Bus system bus with UDisks2 registered on it. Getting
that running unprivileged inside a container turned out to be a dead end —
UDisks2 refuses to claim its D-Bus name unless it's running as root, and
udev's device tagging needs a writable `/sys`, which Docker mounts read-only
by default. Granting either of those to the container is a bigger attack
surface than this needs.

Instead, this image follows the same approach as jlesage's own
`docker-imgburn` and `docker-makemkv`: pass the device node straight through
and let the app talk to it directly. K3b supports this via manual device
registration, which bypasses Solid entirely — once added, K3b hands the
actual burn to `cdrdao`/`wodim`/`growisofs` against the device path, no
UDisks2 involved.

## One-time setup after first deploy

1. Deploy the container (see `docker-compose.yml`).
2. Open `http://<host>:5800` in a browser.
3. If K3b shows "No optical drive found": Settings → Setup Devices → Add
   Device → enter `/dev/sr0`.
4. This is saved under `/config`, which is a persistent volume, so it
   survives `docker compose up -d --force-recreate`.

## Devices and permissions

- `/dev/sr0` (and `/dev/sg3` if your drive needs generic SCSI access) must be
  passed through via `devices:` in the compose file.
- `SUP_GROUP_IDS` should match the host GID that owns `/dev/sr0` (commonly
  the `cdrom` group, GID 24 on Debian/Ubuntu-based hosts — check with
  `ls -la /dev/sr0` on the host and adjust if different).
- `cap_add: SYS_RAWIO` is required for the low-level SCSI commands K3b's
  backends issue.

## Troubleshooting

Check container logs first:

```
docker logs -f k3b
```

You should see `dbus` and `app` start cleanly with no permission errors. If
`dbus` fails, check `/config` ownership and the `USER_ID`/`GROUP_ID` env vars
match what owns your config volume on the host.

If K3b still can't see `/dev/sr0` after manually adding it, confirm the
device is actually visible and readable inside the container:

```
docker exec -it k3b ls -la /dev/sr0
docker exec -it k3b cdrecord -scanbus
```
