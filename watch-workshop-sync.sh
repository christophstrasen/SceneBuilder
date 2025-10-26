#!/usr/bin/env bash
set -euo pipefail

# Run from repo root (which itself contains Contents/, preview.png, etc.)
SRC_MOD_DIR="."
DEST_WRAPPER="$HOME/Zomboid/Workshop/SceneBuilder"

echo "Watching '$SRC_MOD_DIR' → '$DEST_WRAPPER'"

RSYNC_EXCLUDES=(
  "--exclude=.git/" "--exclude=.github/" "--exclude=.idea/" "--exclude=.vscode/"
  "--exclude=.direnv/" "--exclude=dist/" "--exclude=build/" "--exclude=out/"
  "--exclude=tmp/" "--exclude=__pycache__/" "--exclude=node_modules/"
  "--exclude=docs/" "--exclude=tests/" "--exclude=.DS_Store"
)

sync_once() {
  rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$SRC_MOD_DIR/" "$DEST_WRAPPER/"
  echo "[synced] $(date '+%H:%M:%S')"
}

sync_once
echo "Watching for changes…"
while inotifywait -r -e modify,create,delete,move "$SRC_MOD_DIR"; do
  sync_once
done