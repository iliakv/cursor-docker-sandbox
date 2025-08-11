#!/usr/bin/env bash
set -euo pipefail

API_URL="https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable"

echo "Fetching latest Cursor AppImage URL..."
# Extract downloadUrl using jq or grep/sed if jq not available
if command -v jq >/dev/null 2>&1; then
    DOWNLOAD_URL=$(curl -s "$API_URL" | jq -r '.downloadUrl')
else
    DOWNLOAD_URL=$(curl -s "$API_URL" | grep -oP '"downloadUrl"\s*:\s*"\K[^"]+')
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "Error: Could not retrieve download URL."
    exit 1
fi

FILENAME=$(basename "$DOWNLOAD_URL")
echo "Latest Cursor AppImage: $FILENAME"

# Download the file
if [[ -f "$FILENAME" ]]; then
    echo "$FILENAME already exists, skipping download."
else
    echo "Downloading $FILENAME..."
    curl -L --retry 5 --retry-delay 2 -o "$FILENAME" "$DOWNLOAD_URL"
fi

# Make executable
chmod +x "$FILENAME"

# Update symbolic link
ln -sf "$FILENAME" cursor.AppImage
echo "Symlink created: cursor.AppImage -> $FILENAME"

echo "Done. Run it with: ./cursor.AppImage"
