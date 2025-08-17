#!/bin/bash
set -x
set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/config.sh"

IMAGE_NAME="${IMAGE_NAME:-cursor-x11}"

DO_CLEAN=0
DO_GRANT_ACL=0
DO_AS_OWNER=0
DO_USERNS_HOST=0
for arg in "$@"; do
  case "$arg" in
    --clean) DO_CLEAN=1 ;;
    --grant-acl) DO_GRANT_ACL=1 ;;
    --as-owner) DO_AS_OWNER=1 ;;
    --userns-host) DO_USERNS_HOST=1 ;;
  esac
done

if [[ "$DO_CLEAN" -eq 1 ]]; then
  echo "Cleaning persisted state at ${PERSIST_BASE} ..."
  for d in cursor config cache mozilla local; do
    [ -d "${PERSIST_BASE}/${d}" ] || continue
    ts=$(date +%Y%m%d-%H%M%S)
    mv "${PERSIST_BASE}/${d}" "${PERSIST_BASE}/${d}.bak-${ts}"
    echo "moved ${PERSIST_BASE}/${d} -> ${PERSIST_BASE}/${d}.bak-${ts}"
  done
fi

mkdir -p "${PERSIST_BASE}/config"
mkdir -p "${PERSIST_BASE}/cache"
mkdir -p "${PERSIST_BASE}/cursor"
mkdir -p "${PERSIST_BASE}/mozilla"
mkdir -p "${PERSIST_BASE}/local"

if [[ "$DO_GRANT_ACL" -eq 1 ]]; then
  if ! command -v setfacl >/dev/null 2>&1; then
    echo "'setfacl' not found on host. Install 'acl' package or grant perms manually."
    exit 1
  fi
fi

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

RO_LIST=$(mktemp)
RW_LIST=$(mktemp)
chmod 644 "$RO_LIST" "$RW_LIST"

declare -a VOLUMES
declare -a RW_HOSTS

# RO binds
while IFS= read -r line; do
  line=$(echo "$line" | trim)
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  host="${line%%->*}"; cont="${line##*->}"
  VOLUMES+=( "--volume" "${host}:${cont}:ro" )
  printf '%s\n' "${cont}" >> "${RO_LIST}"
done <<< "${RO_BINDS}"

# RW binds
while IFS= read -r line; do
  line=$(echo "$line" | trim)
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  host="${line%%->*}"; cont="${line##*->}"
  VOLUMES+=( "--volume" "${host}:${cont}:rw" )
  printf '%s\n' "${cont}" >> "${RW_LIST}"
  RW_HOSTS+=( "${host}" )
  if [[ "$DO_GRANT_ACL" -eq 1 ]]; then
    echo "Granting ACL rwx to uid:${CONTAINER_UID} on ${host} ..."
    sudo setfacl -m u:${CONTAINER_UID}:rwx "${host}" || echo "ACL grant failed on ${host} (FS may not support ACLs)"
    sudo setfacl -d -m u:${CONTAINER_UID}:rwx "${host}" || true
  fi
done <<< "${RW_BINDS}"

# Runtime identity
TARGET_UID="${CONTAINER_UID}"
TARGET_GID="${CONTAINER_GID}"
if [[ "$DO_AS_OWNER" -eq 1 ]]; then
  if [[ "${#RW_HOSTS[@]}" -eq 0 ]]; then
    echo "--as-owner requires at least one RW bind in config.sh"
    exit 1
  fi
  REF="${RW_HOSTS[0]}"
  if [[ ! -e "$REF" ]]; then
    echo "RW reference path not found on host: $REF"
    exit 1
  fi
  TARGET_UID=$(stat -c %u "$REF")
  TARGET_GID=$(stat -c %g "$REF")
  echo "Running container as owner of ${REF}: uid=${TARGET_UID} gid=${TARGET_GID}"
fi

# X11 handling
DISPLAY_VAL="${DISPLAY:-}"
if [[ -z "$DISPLAY_VAL" ]]; then
  echo "DISPLAY is empty, cannot open X11"
  exit 1
fi

# Local X server via Unix socket
if [[ "$DISPLAY_VAL" =~ ^:([0-9]+) ]]; then
  if [[ "${USE_X11}" -eq 1 ]]; then
    xhost +local:docker >/dev/null
    VOLUMES+=( "--volume" "/tmp/.X11-unix:/tmp/.X11-unix:ro" )
  fi
else
  # SSH forwarded display over TCP, mount real Xauthority
  AUTH_FILE="${XAUTHORITY:-$HOME/.Xauthority}"
  if [[ -r "$AUTH_FILE" ]]; then
    VOLUMES+=( "--volume" "${AUTH_FILE}:/tmp/.Xauthority:ro" )
    ENV_XAUTH=( "--env" "XAUTHORITY=/tmp/.Xauthority" )
  else
    echo "XAUTHORITY not readable at ${AUTH_FILE}. Run without sudo, or export XAUTHORITY=~/.Xauthority"
    exit 1
  fi
fi

# Verify image
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Image '${IMAGE_NAME}' not found. Run ./build.sh first."
  exit 1
fi

# Env
ENV_ARGS=(
  "--env" "DISPLAY=${DISPLAY_VAL}"
  "--env" "XDG_CONFIG_HOME=/home/cursoruser/.config"
  "--env" "XDG_CACHE_HOME=/home/cursoruser/.cache"
  "--env" "APPIMAGE_CONTAINER_DIR=${APPIMAGE_CONTAINER_DIR}"
  "--env" "APPIMAGE_FILENAME=${APPIMAGE_FILENAME}"
  "--env" "TARGET_UID=${TARGET_UID}"
  "--env" "TARGET_GID=${TARGET_GID}"
)
# Add XAUTH env if set
if [[ -n "${ENV_XAUTH+set}" ]]; then
  ENV_ARGS+=( "${ENV_XAUTH[@]}" )
fi

# Persisted dirs
VOLUMES+=( "--volume" "${PERSIST_BASE}/cursor:/home/cursoruser/.cursor:rw" )
VOLUMES+=( "--volume" "${PERSIST_BASE}/config:/home/cursoruser/.config:rw" )
VOLUMES+=( "--volume" "${PERSIST_BASE}/cache:/home/cursoruser/.cache:rw" )
VOLUMES+=( "--volume" "${PERSIST_BASE}/mozilla:/home/cursoruser/.mozilla:rw" )
VOLUMES+=( "--volume" "${PERSIST_BASE}/local:/home/cursoruser/.local:rw" )





# Mount verify lists
VOLUMES+=( "--volume" "${RO_LIST}:/etc/cursor-ro.list:ro" )
VOLUMES+=( "--volume" "${RW_LIST}:/etc/cursor-rw.list:ro" )

# Optional extra docker args
declare -a EXTRA_RUN_ARGS
EXTRA_RUN_ARGS=()
if [[ "$DO_USERNS_HOST" -eq 1 ]]; then
  EXTRA_RUN_ARGS+=( "--userns=host" )
fi

docker run --rm -it \
  --device /dev/fuse \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  --shm-size="${SHM_SIZE}" \
  --net=host \
  --tmpfs "/home/cursoruser/writable:exec,uid=${TARGET_UID},gid=${TARGET_GID}" \
  --tmpfs "/run:uid=0,gid=0,mode=755" \
  "${ENV_ARGS[@]}" \
  "${VOLUMES[@]}" \
  "${EXTRA_RUN_ARGS[@]}" \
  "${IMAGE_NAME}"

# Cleanup temp lists
rm -f "${RO_LIST}" "${RW_LIST}"

if [[ "${USE_X11}" -eq 1 && "$DISPLAY_VAL" =~ ^:([0-9]+) ]]; then
  xhost -local:docker >/dev/null
fi

