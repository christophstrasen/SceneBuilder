#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

MOD_ID="SceneBuilder"

RED_BG="\033[41;97m"
GREEN="\033[32m"
RESET="\033[0m"

check_png_plausible() {
  local path="$1"
  local min_bytes="$2"

  if [ ! -f "$path" ]; then
    echo -e "${RED_BG}[assets FAIL]${RESET} missing: $path"
    return 1
  fi

  if command -v file >/dev/null; then
    local mt
    mt="$(file -b --mime-type "$path" || true)"
    if [ "$mt" != "image/png" ]; then
      echo -e "${RED_BG}[assets FAIL]${RESET} not a PNG ($mt): $path"
      return 1
    fi
  fi

  local size
  size="$(stat -c '%s' "$path" 2>/dev/null || wc -c <"$path")"
  if [ "$size" -lt "$min_bytes" ]; then
    echo -e "${RED_BG}[assets FAIL]${RESET} too small (${size}B): $path"
    return 1
  fi

  return 0
}

export_svg_png() {
  local svg="$1"
  local out="$2"
  local w="$3"
  local h="$4"
  local min_bytes="$5"

  if [ ! -f "$svg" ]; then
    echo -e "${RED_BG}[assets FAIL]${RESET} missing SVG: $svg"
    return 1
  fi

  mkdir -p "$(dirname "$out")"

  if ! command -v inkscape >/dev/null; then
    echo -e "${RED_BG}[assets FAIL]${RESET} inkscape not found in PATH"
    return 1
  fi

  # Skip regeneration when the output is newer than the source SVG.
  # This prevents watch scripts from self-triggering loops on every sync.
  if [ "${FORCE_ASSETS:-0}" != "1" ] && [ -f "$out" ] && [ "$out" -nt "$svg" ]; then
    if check_png_plausible "$out" "$min_bytes"; then
      if [ "${VERBOSE:-0}" = "1" ]; then
        echo "[assets skip] $out"
      fi
      return 0
    fi
  fi

  inkscape "$svg" \
    --export-type=png \
    --export-filename="$out" \
    -w "$w" -h "$h" \
    >/dev/null

  check_png_plausible "$out" "$min_bytes"
}

export_svg_png "512.svg" "Contents/mods/$MOD_ID/42/poster.png" 512 512 2000
export_svg_png "256.svg" "preview.png" 256 256 1000
export_svg_png "64.svg" "Contents/mods/$MOD_ID/42/icon_64.png" 64 64 400

echo -e "${GREEN}[assets ok]${RESET}"
