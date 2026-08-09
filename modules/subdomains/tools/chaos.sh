#!/bin/bash
# Contrato V2 — zero vazamento no terminal
if [[ "${1:-}" == "--info" ]]; then
  echo "name=chaos"
  echo "version=1.0"
  echo "description=ProjectDiscovery Chaos client"
  exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

BIN="${CHAOS_BIN:-chaos}"

if ! command -v "$BIN" >/dev/null 2>&1; then
  echo "binary not found: $BIN" >> "$STDERR_FILE"
  exit 127
fi

"$BIN" -dL "$INPUT_FILE" -silent -o "$STDOUT_FILE" >>"$STDERR_FILE" 2>&1 || true

exit 0
