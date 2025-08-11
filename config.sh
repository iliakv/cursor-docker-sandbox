# Image tag
IMAGE_NAME="cursor-x11"

# AppImage location on host and filename
APPIMAGE_HOST_DIR="/home/ilia/cursor"
APPIMAGE_FILENAME="cursor.AppImage"
# Where it should appear inside the container (directory)
APPIMAGE_CONTAINER_DIR="/appimage"

# Read-only bind mounts: one "host->container" mapping per line
RO_BINDS="
/mnt/share->/mnt/share
${APPIMAGE_HOST_DIR}->${APPIMAGE_CONTAINER_DIR}
"

# Read-write bind mounts: one "host->container" mapping per line
RW_BINDS="
/mnt/share/ilia->/mnt/share/ilia
"

# Persistent state base dir on host for config/cache/extensions
PERSIST_BASE="${HOME}/.docker-cursor"

# Container user identity
CONTAINER_UID=1000
CONTAINER_GID=1000

# X11 usage, leave 1 for X11
USE_X11=1

# Shared memory and tmpfs sizes
SHM_SIZE="1g"

# Optional: first run you can grant ACLs to keep root ownership on RW mounts
# start.sh --grant-acl will apply setfacl for CONTAINER_UID on each RW host dir
