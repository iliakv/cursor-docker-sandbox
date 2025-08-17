#!/bin/bash
set -euo pipefail

# Runtime identity from start.sh
TARGET_UID="${TARGET_UID:-1000}"
TARGET_GID="${TARGET_GID:-1000}"

# Allow any uid to traverse home and execute launcher
chmod a+rx /home/xuser || true
chmod a+rx /home/xuser/run_cursor.sh || true

# Ensure machine id for D-Bus
if [ ! -s /etc/machine-id ]; then
  if command -v dbus-uuidgen >/dev/null 2>&1; then
    dbus-uuidgen > /etc/machine-id
  else
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
  fi
fi
if [ ! -e /var/lib/dbus/machine-id ]; then
  mkdir -p /var/lib/dbus
  ln -sf /etc/machine-id /var/lib/dbus/machine-id
fi

# Provide NSS entries for arbitrary TARGET_UID and TARGET_GID
if ! getent group "${TARGET_GID}" >/dev/null 2>&1; then
  echo "xgroup:x:${TARGET_GID}:" >> /etc/group
fi
if ! getent passwd "${TARGET_UID}" >/dev/null 2>&1; then
  echo "xuser:x:${TARGET_UID}:${TARGET_GID}:Runtime User:/home/xuser:/bin/bash" >> /etc/passwd
fi


# Ensure Firefox profile root is present and writable by runtime uid
mkdir -p /home/xuser/.mozilla
chown -R "${TARGET_UID}:${TARGET_GID}" /home/xuser/.mozilla

# Start system D-Bus
mkdir -p /run/dbus
chmod 755 /run /run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || \
  dbus-daemon --system --address=unix:path=/run/dbus/system_bus_socket --fork

# Drop privileges and start
export HOME=/home/xuser
exec gosu "${TARGET_UID}:${TARGET_GID}" /home/xuser/run_cursor.sh



