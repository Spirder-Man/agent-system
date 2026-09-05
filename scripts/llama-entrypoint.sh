#!/bin/sh
# Probe shared libraries then exec llama-server (b5092+ is dynamically linked).
set -eu

BIN="${LLAMA_SERVER_BIN:-/opt/llama/bin/llama-server}"
if [ ! -x "$BIN" ]; then
  BIN=/usr/local/bin/llama-server
fi

MISSING=$(ldd "$BIN" 2>/dev/null | grep "not found" | tr '\n' ';' || true)
if [ -n "$MISSING" ]; then
  echo "llama-server missing libraries: $MISSING" >&2
fi

exec "$BIN" "$@"
