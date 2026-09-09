#!/usr/bin/env bash
# Pack three source-only release archives. Delegates to pack-source-releases.py
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:-v0.1.0}"
if command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/scripts/pack-source-releases.py" "$VERSION"
elif command -v py >/dev/null 2>&1; then
  py -3 "$ROOT/scripts/pack-source-releases.py" "$VERSION"
else
  echo "python3 not found" >&2
  exit 1
fi
