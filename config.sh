# --- Dynamic per-user config -----------------------------------------------

# Resolve current user robustly, works under sudo too
CURRENT_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Prefer vault-style home if it exists, else fall back to $HOME
VAULT_HOME="/home/vault/users/${CURRENT_USER}"
HOST_HOME="${HOME:-/home/${CURRENT_USER}}"
BASE_HOME="$([ -d "$VAULT_HOME" ] && echo "$VAULT_HOME" || echo "$HOST_HOME")"

# Image tag
IMAGE_NAME="cursor-x11"

# AppImage location on host and filename
APPIMAGE_HOST_DIR="${BASE_HOME}/cursor-docker-sandbox"
APPIMAGE_FILENAME="cursor.AppImage"

# Where it should appear inside the container
APPIMAGE_CONTAINER_DIR="/appimage"

# Read-only bind mounts, one "host->container" per line
RO_BINDS="
/mnt/ftd->/mnt/ftd
${APPIMAGE_HOST_DIR}->${APPIMAGE_CONTAINER_DIR}
"

# Read-write bind mounts, one "host->container" per line
RW_BINDS="
${BASE_HOME}/monitor_cursor->${BASE_HOME}/monitor_cursor
"

# Persistent state base dir on host for config, cache, extensions
PERSIST_BASE="${HOST_HOME}/.docker-cursor"

# Container user identity (will be set dynamically to match host user)
# CONTAINER_UID and CONTAINER_GID are now determined at runtime

# X11 usage
USE_X11=1

# Shared memory and tmpfs sizes
SHM_SIZE="1g"

# ---------------------------------------------------------------------------
# Notes:
# - Run scripts without sudo so DISPLAY and XAUTHORITY are correct.
# - If you must use sudo, prefer: sudo -E ./start.sh
# - You can override BASE_HOME for testing:
#     BASE_HOME="/some/other/path" ./start.sh
# ---------------------------------------------------------------------------

