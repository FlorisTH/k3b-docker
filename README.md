# k3b-docker

K3b running in a `jlesage/baseimage-gui` container, accessed via a web browser
on port 5800.

## How drive detection works

Modern (KF5-based) K3b has no manual "add device" fallback in its UI - it
relies entirely on KDE's Solid framework, which in turn requires UDisks2 to
be running and to know about the drive. Getting that working unprivileged
inside a container needs several pieces working together, in this order:

1. **`dbus`** - the system message bus. Runs as the unprivileged app user
   (the `<user>messagebus</user>` directive is stripped from its config at
   build time, since a non-root process can't switch users).
2. **`udevd`** - runs as root (the one service in this image that does).
   Needed so device events can be processed at all.
3. **`udev-trigger`** - a one-shot step that asks the kernel to re-emit
   "add" events for devices that already existed when the container booted
   (a cold boot never triggers these automatically). This requires write
   access to `/sys`, which is why the compose file mounts it `rw`.
4. **`udisksd`** - waits for both `dbus` and `udev-trigger`, then starts,
   claims the `org.freedesktop.UDisks2` D-Bus name (permitted via the
   `k3b-udisks2.conf` policy file for the unprivileged app user), and reads
   the udev database populated in step 3.
5. **`app`** (K3b itself) - waits for `udisksd`, then starts. Solid asks
   UDisks2 for the device list, gets it, and K3b sees `/dev/sr0`.

The empty `*.dep` files in `rootfs/etc/services.d/*/` are what wire this
dependency order into the supervisor - each is just a marker file named
after the service it depends on.

## Security note on `/sys`

The compose file mounts `/sys:/sys:rw`. This is broader than strictly
necessary (only one device's uevent file actually needs to be written) but
is the standard, well-tested pattern for this kind of hardware-access
container. A narrower alternative is bind-mounting only the specific PCI
subtree your drive is attached to, at the cost of that mount breaking if the
drive moves to a different port. See the Dockerfile/compose comments for
where to make that change if you want to tighten it later.

Since Docker does not remap container UIDs by default, root inside this
container is the same root as on the host - `udevd` running as root here is
a real privilege grant, not a sandboxed one. Don't expose extra ports or
add capabilities beyond what's already here without re-checking this note.

## Devices and permissions

- `/dev/sr0` (and `/dev/sg3` if your drive needs generic SCSI access) must be
  passed through via `devices:` in the compose file.
- `SUP_GROUP_IDS` should match the host GID that owns `/dev/sr0` (confirmed
  as `24`, the `cdrom` group, via `getent group cdrom` on TrueNAS).
- `cap_add: SYS_RAWIO` is required for the low-level SCSI commands K3b's
  backends issue.

## Deploying

```bash
docker compose pull k3b
docker compose up -d --force-recreate k3b
docker logs -f k3b
```

Expected boot order in the logs: `dbus` starts clean, `udevd` starts,
`udev-trigger` runs and exits (status 0), `udisksd` starts and logs
`Acquired the name org.freedesktop.UDisks2 on the system message bus`, then
`app` (K3b) starts. No "Permission denied" or "Read-only file system"
errors anywhere in that sequence.

## Troubleshooting

If `udisksd` starts but the device still isn't found, check the chain
directly:

```bash
docker exec -it k3b udevadm info /dev/sr0
docker exec -it k3b ls -la /run/udev/data/ | grep -i sr
docker exec -it k3b udisksctl status
```

- `udevadm info` empty -> the kernel doesn't see the device at all; check the
  `devices:` passthrough in compose.
- `/run/udev/data/` empty -> `udev-trigger` didn't actually tag the device;
  confirm `/sys:/sys:rw` is really applied (`docker inspect k3b` and check
  the Mounts section), and test manually:
  `docker exec -it k3b sh -c "echo add > /sys/class/block/sr0/uevent"` -
  this should return silently, not "Read-only file system".
- `udisksctl status` prints only headers, no rows -> `udisksd` is running
  but sees no devices in its database; re-check the previous step.

If text isn't rendering anywhere in the GUI (blank dialogs, blank labels),
that's a missing-font issue, unrelated to the above - confirm `font-noto`
(or `ttf-dejavu` if you swapped it in for a smaller image) is actually
present: `docker exec -it k3b fc-list`.
