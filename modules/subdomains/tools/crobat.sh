#!/bin/bash
# Contrato V2 — zero vazamento no terminal
if [[ "${1:-}" == "--info" ]]; then
  echo "name=crobat"
  echo "version=1.0"
  echo "description=Crobat subdomain enumeration"
  exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

BIN="${CROBAT_BIN:-crobat}"

if ! command -v "$BIN" >/dev/null 2>&1; then
  echo "binary not found: $BIN" >> "$STDERR_FILE"
  exit 127
fi

while read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  "$BIN" -s "$domain" >>"$STDOUT_FILE" 2>>"$STDERR_FILE" || true
done < "$INPUT_FILE"

exit 0
