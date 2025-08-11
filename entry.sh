#!/bin/bash
set -euo pipefail

mkdir -p /run/dbus
chmod 755 /run /run/dbus
if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
  dbus-daemon --system --address=unix:path=/run/dbus/system_bus_socket --fork
fi

export HOME=/home/cursoruser
exec gosu 1000:1000 /home/cursoruser/run_cursor.sh
