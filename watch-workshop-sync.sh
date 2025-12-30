#!/usr/bin/env bash
set -euo pipefail

echo "[deprecated] use ./dev/watch.sh (defaults to TARGET=workshop)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/dev/watch.sh" "$@"
