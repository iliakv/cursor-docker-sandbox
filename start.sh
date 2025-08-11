#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/config.sh"

IMAGE_NAME="${IMAGE_NAME:-cursor-x11}"

DO_CLEAN=0
DO_GRANT_ACL=0
for arg in "$@"; do
  case "$arg" in
    --clean) DO_CLEAN=1 ;;
    --grant-acl) DO_GRANT_ACL=1 ;;
  esac
done

if [[ "$DO_CLEAN" -eq 1 ]]; then
  echo "🧹 Cleaning persisted state at ${PERSIST_BASE} ..."
  for d in cursor config cache; do
    [ -d "${PERSIST_BASE}/${d}" ] || continue
    ts=$(date +%Y%m%d-%H%M%S)
    mv "${PERSIST_BASE}/${d}" "${PERSIST_BASE}/${d}.bak-${ts}"
    echo "  moved ${PERSIST_BASE}/${d} -> ${PERSIST_BASE}/${d}.bak-${ts}"
  done
fi

mkdir -p "${PERSIST_BASE}/config" "${PERSIST_BASE}/cache" "${PERSIST_BASE}/cursor"

# Optional ACL grant while keeping root ownership on host RW dirs
if [[ "$DO_GRANT_ACL" -eq 1 ]]; then
  if ! command -v setfacl >/dev/null 2>&1; then
    echo "❌ 'setfacl' not found on host. Install 'acl' package or grant perms manually."
    exit 1
  fi
fi

# Parse RO/RW maps, build arrays and write verify lists
RO_LIST=$(mktemp)
RW_LIST=$(mktemp)
declare -a VOLUMES

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

while IFS= read -r line; do
  line=$(echo "$line" | trim)
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  host="${line%%->*}"; cont="${line##*->}"
  VOLUMES+=( "--volume" "${host}:${cont}:ro" )
  printf '%s\n' "${cont}" >> "${RO_LIST}"
done <<< "${RO_BINDS}"

while IFS= read -r line; do
  line=$(echo "$line" | trim)
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  host="${line%%->*}"; cont="${line##*->}"
  VOLUMES+=( "--volume" "${host}:${cont}:rw" )
  printf '%s\n' "${cont}" >> "${RW_LIST}"
  if [[ "$DO_GRANT_ACL" -eq 1 ]]; then
    echo "🔐 Granting ACL rwx to uid:${CONTAINER_UID} on ${host} ..."
    sudo setfacl -m u:${CONTAINER_UID}:rwx "${host}"
    sudo setfacl -d -m u:${CONTAINER_UID}:rwx "${host}" || true
  fi
done <<< "${RW_BINDS}"

# Mount X11 if requested
if [[ "${USE_X11}" -eq 1 ]]; then
  xhost +local:docker >/dev/null
  VOLUMES+=( "--volume" "/tmp/.X11-unix:/tmp/.X11-unix:ro" )
fi

# Always add persistent dirs
VOLUMES+=( "--volume" "${PERSIST_BASE}/cursor:/home/cursoruser/.cursor:rw" )
VOLUMES+=( "--volume" "${PERSIST_BASE}/config:/home/cursoruser/.config:rw" )
VOLUMES+=( "--volume" "${PERSIST_BASE}/cache:/home/cursoruser/.cache:rw" )

# Verify image exists
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "❌ Image '${IMAGE_NAME}' not found. Run ./build.sh first."
  exit 1
fi

# Environment for the container
ENV_ARGS=(
  "--env" "DISPLAY=${DISPLAY}"
  "--env" "XDG_CONFIG_HOME=/home/cursoruser/.config"
  "--env" "XDG_CACHE_HOME=/home/cursoruser/.cache"
  "--env" "APPIMAGE_CONTAINER_DIR=${APPIMAGE_CONTAINER_DIR}"
  "--env" "APPIMAGE_FILENAME=${APPIMAGE_FILENAME}"
)

# Mount the verify lists into the container
VOLUMES+=( "--volume" "${RO_LIST}:/etc/cursor-ro.list:ro" )
VOLUMES+=( "--volume" "${RW_LIST}:/etc/cursor-rw.list:ro" )

# Run
docker run --rm -it \
  --device /dev/fuse \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  --shm-size="${SHM_SIZE}" \
  --net=host \
  --tmpfs "/home/cursoruser/writable:exec,uid=${CONTAINER_UID},gid=${CONTAINER_GID}" \
  --tmpfs "/run:uid=0,gid=0,mode=755" \
  "${ENV_ARGS[@]}" \
  "${VOLUMES[@]}" \
  "${IMAGE_NAME}"

# Cleanup temp lists
rm -f "${RO_LIST}" "${RW_LIST}"

if [[ "${USE_X11}" -eq 1 ]]; then
  xhost -local:docker >/dev/null
fi
