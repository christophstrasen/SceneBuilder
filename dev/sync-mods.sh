#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MOD_ID="SceneBuilder"
SRC_MOD_DIR="$REPO_ROOT/Contents/mods/$MOD_ID"

PZ_MODS_DIR="${PZ_MODS_DIR:-$HOME/Zomboid/mods}"
DEST_MOD_DIR="$PZ_MODS_DIR/$MOD_ID"

"$SCRIPT_DIR/build-assets.sh"

if [ ! -d "$SRC_MOD_DIR" ]; then
  echo "[error] missing mod folder: $SRC_MOD_DIR"
  exit 1
fi

mkdir -p "$DEST_MOD_DIR"
rsync -a --delete "$SRC_MOD_DIR/" "$DEST_MOD_DIR/"

echo "[synced] $MOD_ID -> $DEST_MOD_DIR"

