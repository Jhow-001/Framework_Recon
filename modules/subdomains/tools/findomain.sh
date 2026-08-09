#!/bin/bash
# Contrato V2 — zero vazamento no terminal
if [[ "${1:-}" == "--info" ]]; then
  echo "name=findomain"
  echo "version=1.0"
  echo "description=Findomain subdomain finder"
  exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

BIN="${FINDOMAIN_BIN:-findomain}"

if ! command -v "$BIN" >/dev/null 2>&1; then
  echo "binary not found: $BIN" >> "$STDERR_FILE"
  exit 127
fi

"$BIN" -f "$INPUT_FILE" -q --unique-output "$STDOUT_FILE" >>"$STDERR_FILE" 2>&1 || true

exit 0
