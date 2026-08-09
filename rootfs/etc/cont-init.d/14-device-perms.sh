#!/bin/sh

# Ensure the udev rules directory exists
mkdir -p /etc/udev/rules.d/

# Create a udev rule to force rw permissions for everyone on optical and scsi nodes
echo 'SUBSYSTEM=="block", KERNEL=="sr*", MODE="0666"' > /etc/udev/rules.d/99-k3b.rules
echo 'SUBSYSTEM=="scsi_generic", KERNEL=="sg*", MODE="0666"' >> /etc/udev/rules.d/99-k3b.rules

# Also run a manual chmod just to catch any edge cases before udev fully kicks in
chmod 666 /dev/sr* /dev/sg* 2>/dev/null || true