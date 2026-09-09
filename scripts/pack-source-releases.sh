#!/usr/bin/env bash
# Pack three source-only release archives (cpu / gpu / docker). No GGUF.
# Usage from repo root: bash scripts/pack-source-releases.sh [v0.1.0]
set -euo pipefail

VERSION="${1:-v0.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "not a git repo" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Warning: working tree is not clean. git archive uses HEAD, not uncommitted files."
fi

DIST="$ROOT/dist"
STAGING="$DIST/_staging"
mkdir -p "$DIST"
rm -rf "$STAGING"
mkdir -p "$STAGING"

pack() {
  local name="$1"
  local start="$2"
  local folder="cangwei-${name}-${VERSION}"
  local tar_tmp="$STAGING/${folder}-src.tar"
  git archive --format=tar --prefix="${folder}/" HEAD -o "$tar_tmp"
  tar -xf "$tar_tmp" -C "$STAGING"
  rm -f "$tar_tmp"
  cp "$ROOT/$start" "$STAGING/$folder/START.md"
  rm -f "$DIST/${folder}.zip" "$DIST/${folder}.tar.gz"
  tar -czf "$DIST/${folder}.tar.gz" -C "$STAGING" "$folder"
  if command -v zip >/dev/null 2>&1; then
    (cd "$STAGING" && zip -qr "$DIST/${folder}.zip" "$folder")
  else
    tar -cf "$DIST/${folder}.zip" -C "$STAGING" "$folder"
    echo "warning: zip not found, ${folder}.zip is an uncompressed tar named .zip" >&2
  fi
  echo "Wrote $DIST/${folder}.zip"
  echo "Wrote $DIST/${folder}.tar.gz"
}

pack cpu    scripts/packaging/START-cpu.md
pack gpu    scripts/packaging/START-gpu.md
pack docker scripts/packaging/START-docker.md

rm -rf "$STAGING"
echo "Done. Files in $DIST"
ls -lh "$DIST"
