#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET="${TARGET:-workshop}" # mods|workshop
WATCH_MODE="${WATCH_MODE:-payload}" # payload|repo

sync_once() {
  case "$TARGET" in
    mods) "$SCRIPT_DIR/sync-mods.sh" ;;
    workshop) "$SCRIPT_DIR/sync-workshop.sh" ;;
    *)
      echo "[error] unknown TARGET='$TARGET' (expected 'mods' or 'workshop')"
      exit 1
      ;;
  esac
}

compute_fingerprint() {
  local paths=(
    "$REPO_ROOT/Contents/mods/SceneBuilder"
    "$REPO_ROOT/workshop.txt"
    "$REPO_ROOT/preview.png"
    "$REPO_ROOT/256.svg"
    "$REPO_ROOT/512.svg"
    "$REPO_ROOT/64.svg"
  )

  find "${paths[@]}" -type f 2>/dev/null \
    | LC_ALL=C sort \
    | xargs -I{} stat -c '%n %s %Y' {} 2>/dev/null \
    | sha1sum \
    | awk '{print $1}'
}

echo "Watching SceneBuilder (TARGET=$TARGET)…"
sync_once

if command -v inotifywait >/dev/null; then
  case "$WATCH_MODE" in
    payload)
      WATCH_PATHS=(
        "$REPO_ROOT/Contents/mods/SceneBuilder"
        "$REPO_ROOT/workshop.txt"
        "$REPO_ROOT/preview.png"
        "$REPO_ROOT/256.svg"
        "$REPO_ROOT/512.svg"
        "$REPO_ROOT/64.svg"
      )
      ;;
    repo)
      WATCH_PATHS=("$REPO_ROOT")
      ;;
    *)
      echo "[error] unknown WATCH_MODE='$WATCH_MODE' (expected 'payload' or 'repo')"
      exit 1
      ;;
  esac

  echo "Watching paths:"
  printf '  - %s\n' "${WATCH_PATHS[@]}"
  if [ "$WATCH_MODE" = "payload" ]; then
    echo "Note: edits outside these paths will not trigger a sync."
  fi

  inotifywait -m -q -r -e close_write,modify,attrib,create,delete,move \
    --format '%w%f' \
    "${WATCH_PATHS[@]}" 2>/dev/null |
    while IFS= read -r _path; do
      if [ "${VERBOSE:-0}" = "1" ]; then
        echo "[change] $_path"
      fi
      sync_once
    done
else
  echo "[warn] inotifywait not found; using polling fallback"
  prev="$(compute_fingerprint)"
  while true; do
    sleep 0.5
    next="$(compute_fingerprint)"
    if [ "$next" != "$prev" ]; then
      prev="$next"
      sync_once
    fi
  done
fi

