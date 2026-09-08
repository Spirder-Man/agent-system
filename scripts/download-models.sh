#!/usr/bin/env bash
# Check (and optionally download) GGUF files for llama.cpp.
# Usage from agent-system/:
#   bash scripts/download-models.sh
# Optional: AGENT1_MODEL_BASE_URL=https://example.com/gguf  (no trailing slash)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

MODELS_DIR="${MODELS_PATH:-$PROJECT_DIR/models}"
case "$MODELS_DIR" in
  /*) ;;
  *) MODELS_DIR="$PROJECT_DIR/$MODELS_DIR" ;;
esac

SUMS_FILE="$PROJECT_DIR/models/SHA256SUMS"
BASE_URL="${AGENT1_MODEL_BASE_URL:-}"
BASE_URL="${BASE_URL%/}"

mkdir -p "$MODELS_DIR"

expected_hash() {
  local name="$1"
  [ -f "$SUMS_FILE" ] || { echo "SKIP"; return; }
  awk -v n="$name" '
    $0 ~ /^#/ { next }
    NF >= 2 && $2 == n { print $1; found=1; exit }
    END { if (!found) print "SKIP" }
  ' "$SUMS_FILE"
}

echo "========================================"
echo "  Agent1 models check"
echo "  dir: $MODELS_DIR"
echo "========================================"

fail=0
warn=0

check_one() {
  local name="$1"
  local min_bytes="$2"
  local required="$3"
  local dest="$MODELS_DIR/$name"

  if [ ! -f "$dest" ] && [ -n "$BASE_URL" ]; then
    echo "Downloading $name ..."
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 -o "$dest" "$BASE_URL/$name" || rm -f "$dest"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "$dest" "$BASE_URL/$name" || rm -f "$dest"
    else
      echo "Need curl or wget to download."
    fi
  fi

  if [ ! -f "$dest" ]; then
    if [ "$required" = "1" ]; then
      echo "MISSING (required): $name"
      fail=1
    else
      echo "missing (optional VL): $name"
      warn=1
    fi
    return
  fi

  local len
  len="$(wc -c < "$dest" | tr -d ' ')"
  if [ "$len" -lt "$min_bytes" ]; then
    echo "TOO SMALL: $name ($len bytes, min $min_bytes)"
    if [ "$required" = "1" ]; then fail=1; else warn=1; fi
    return
  fi

  local expect actual
  expect="$(expected_hash "$name")"
  if [ -n "$expect" ] && [ "$expect" != "SKIP" ] && [ "$expect" != "skip" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual="$(sha256sum "$dest" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
      actual="$(shasum -a 256 "$dest" | awk '{print $1}')"
    else
      echo "No sha256sum/shasum; skip hash for $name"
      actual=""
    fi
    expect="$(echo "$expect" | tr 'A-F' 'a-f')"
    if [ -n "$actual" ] && [ "$actual" != "$expect" ]; then
      echo "SHA256 mismatch: $name"
      echo "  expected $expect"
      echo "  actual   $actual"
      if [ "$required" = "1" ]; then fail=1; else warn=1; fi
      return
    fi
  fi

  awk -v n="$name" -v len="$len" 'BEGIN { printf "OK  %s  (%.1f GB)\n", n, len/1024/1024/1024 }'
}

# min bytes: 8B ~1GiB floor; embed/mmproj ~80MiB
check_one "Qwen_Qwen3-8B-Q4_K_M.gguf" 1073741824 1
check_one "nomic-embed-text-v1.5.f16.gguf" 83886080 1
check_one "Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf" 1073741824 0
check_one "mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf" 83886080 0

if [ "$fail" -ne 0 ] || [ "$warn" -ne 0 ]; then
  echo ""
  echo "Copy GGUF files into the models directory. Search keywords:"
  echo "  Qwen3-8B Q4_K_M gguf"
  echo "  nomic-embed-text-v1.5 f16 gguf"
  echo "  Qwen2.5-VL-7B-Instruct Q4_K_M gguf"
  echo "  mmproj Qwen2.5-VL-7B f16 gguf"
  echo "See models/README.md. File names must match compose exactly."
  echo "To download: set AGENT1_MODEL_BASE_URL to a directory URL that hosts those names."
fi

if [ "$warn" -ne 0 ] && [ "$fail" -eq 0 ]; then
  echo ""
  echo "VL files missing: port 8083 OCR/vision will not work; LLM :8080 can still run."
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo ""
echo "Required GGUF files are present."
exit 0
