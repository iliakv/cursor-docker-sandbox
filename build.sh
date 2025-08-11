#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/config.sh"

echo "🔧 Preparing persistent directories..."
mkdir -p "${PERSIST_BASE}/config" "${PERSIST_BASE}/cache" "${PERSIST_BASE}/cursor"

echo "🔨 Building image ${IMAGE_NAME} ..."
docker build -t "${IMAGE_NAME}" .
echo "✅ Build complete."
