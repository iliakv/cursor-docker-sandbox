#!/bin/bash
set -euo pipefail

# Runtime identity from start.sh
TARGET_UID="${TARGET_UID:-1000}"
TARGET_GID="${TARGET_GID:-1000}"
HOST_USERNAME="${HOST_USER:-$(whoami)}"

# Validate required environment variables
if [[ -z "$TARGET_UID" || -z "$TARGET_GID" ]]; then
  echo "ERROR: TARGET_UID and TARGET_GID must be set"
  exit 1
fi

echo "Setting up container for user: ${HOST_USERNAME} (uid=${TARGET_UID}, gid=${TARGET_GID})"

# Create user's home directory
USER_HOME="/home/${HOST_USERNAME}"
mkdir -p "${USER_HOME}"

# Copy scripts to user's home directory
cp /home/workspace/verify_fs.sh "${USER_HOME}/"
cp /home/workspace/run_cursor.sh "${USER_HOME}/"

# Set proper permissions for user's home and scripts
chmod a+rx "${USER_HOME}" || true
chmod +x "${USER_HOME}/verify_fs.sh" "${USER_HOME}/run_cursor.sh" || true
chmod a+rx "${USER_HOME}/run_cursor.sh" || true

# Set HOME environment variable for scripts
export HOME="${USER_HOME}"

# Create writable directory for the user
mkdir -p "${USER_HOME}/writable"
chown -R "${TARGET_UID}:${TARGET_GID}" "${USER_HOME}/writable"

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
  echo "${HOST_USERNAME}:x:${TARGET_GID}:" >> /etc/group
fi
if ! getent passwd "${TARGET_UID}" >/dev/null 2>&1; then
  echo "${HOST_USERNAME}:x:${TARGET_UID}:${TARGET_GID}:Runtime User:${USER_HOME}:/bin/bash" >> /etc/passwd
  echo "Created user entry: ${HOST_USERNAME} (uid=${TARGET_UID}, gid=${TARGET_GID})"
  
  # Set up passwordless sudo for the user
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${HOST_USERNAME}" > "/etc/sudoers.d/010-${HOST_USERNAME}-nopasswd"
  chown root:root "/etc/sudoers.d/010-${HOST_USERNAME}-nopasswd"
  chmod 0440 "/etc/sudoers.d/010-${HOST_USERNAME}-nopasswd"
  echo "Set up passwordless sudo for ${HOST_USERNAME}"
fi


# Ensure Firefox profile root is present and writable by runtime uid
mkdir -p "${USER_HOME}/.mozilla"
chown -R "${TARGET_UID}:${TARGET_GID}" "${USER_HOME}/.mozilla"

# Start system D-Bus
mkdir -p /run/dbus
chmod 755 /run /run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || \
  dbus-daemon --system --address=unix:path=/run/dbus/system_bus_socket --fork

# Final validation - ensure we can switch to the target user
echo "Validating user identity..."
if ! gosu "${TARGET_UID}:${TARGET_GID}" id >/dev/null 2>&1; then
  echo "ERROR: Cannot switch to user ${TARGET_UID}:${TARGET_GID}"
  echo "Current user info:"
  id
  echo "Available users:"
  cat /etc/passwd | grep -E ":(1000|${TARGET_UID}):" || echo "No matching users found"
  exit 1
fi

echo "User identity validated successfully"
echo "Final user info:"
gosu "${TARGET_UID}:${TARGET_GID}" id

# Drop privileges and start
export HOME="${USER_HOME}"
exec gosu "${TARGET_UID}:${TARGET_GID}" "${USER_HOME}/run_cursor.sh"



