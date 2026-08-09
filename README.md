# k3b-docker

A Dockerized version of [K3b](https://userbase.kde.org/K3b), the feature-rich, easy-to-use CD/DVD/Blu-ray burning application for Linux. 

This image is built on top of [jlesage/baseimage-gui](https://github.com/jlesage/docker-baseimage-gui), providing a lightweight Alpine Linux base with a built-in web-based GUI (accessible via your browser) and VNC support.

## Why this image?

Modern versions of K3b rely entirely on the KDE Solid framework and `UDisks2` to discover optical hardware. The old "manual device addition" feature was removed from the application[cite: 7]. 

Because standard Docker containers are isolated from host hardware events, running modern K3b in Docker typically results in a "No optical drive found" error. This image solves that by bundling a full `eudev`, `dbus`, and `udisks2` stack inside the container[cite: 7]. With the correct privileges, the container can actively probe the host's `/sys` tree on boot and accurately map the CD/DVD/Blu-ray drives into K3b natively.

## Usage

Below is a `docker-compose.yml` example. **Please read the Optical Drive Configuration Requirements section below carefully**, as standard device mapping is not enough for K3b to detect the drive.

```yaml
services:
  k3b:
    image: ghcr.io/floristh/k3b-docker:latest
    container_name: k3b
    privileged: true
    devices:
      # Map the optical block device
      - /dev/sr0:/dev/sr0
      # Map the corresponding SCSI generic device
      - /dev/sg3:/dev/sg3
    cap_add:
      - SYS_RAWIO
    environment:
      - USER_ID=1000
      - GROUP_ID=1000
      # Must match the host's group ID for /dev/sr0 (e.g., 24 for cdrom)
      - SUP_GROUP_IDS=24
      - TZ=Europe/Amsterdam
    ports:
      - '5800:5800'
    volumes:
      - /path/to/k3b-config:/config:rw
      - /path/to/storage:/storage:rw
      # Required for internal udev device discovery
      - /sys:/sys:rw
    restart: unless-stopped
