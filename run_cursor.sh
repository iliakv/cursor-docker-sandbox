#!/bin/bash
set -euo pipefail

# Verify mounts and permissions
/home/xuser/verify_fs.sh

echo "Launching Cursor AppImage with system+session D-Bus and software GL..."

# Private session D-Bus
SESSION_BUS="/tmp/dbus-session.sock"
[ -S "$SESSION_BUS" ] && rm -f "$SESSION_BUS"
dbus-daemon --session --address="unix:path=${SESSION_BUS}" --fork
export DBUS_SESSION_BUS_ADDRESS="unix:path=${SESSION_BUS}"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"

# Browser for xdg-open
export BROWSER=/usr/bin/firefox

# Software GL via ANGLE SwiftShader
export ELECTRON_OZONE_PLATFORM_HINT=x11
export LIBGL_ALWAYS_SOFTWARE=1
export ANGLE_DEFAULT_PLATFORM=swiftshader
export LIBGL_DEBUG=quiet
export MESA_DEBUG=silent

WRITABLE_DIR="/home/xuser/writable"
mkdir -p "${WRITABLE_DIR}"

# Resolve AppImage path from env
APPIMAGE_CONTAINER_DIR="${APPIMAGE_CONTAINER_DIR:-/appimage}"
APPIMAGE_FILENAME="${APPIMAGE_FILENAME:-cursor.AppImage}"
APPIMAGE_SRC="${APPIMAGE_CONTAINER_DIR%/}/${APPIMAGE_FILENAME}"

cp "${APPIMAGE_SRC}" "${WRITABLE_DIR}/cursor.AppImage"
chmod +x "${WRITABLE_DIR}/cursor.AppImage"

exec "${WRITABLE_DIR}/cursor.AppImage" --no-sandbox --disable-gpu

