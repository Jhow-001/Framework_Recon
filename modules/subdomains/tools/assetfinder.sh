#!/bin/bash
# Contrato V2 — zero vazamento no terminal
if [[ "${1:-}" == "--info" ]]; then
  echo "name=assetfinder"
  echo "version=1.0"
  echo "description=Find domains and subdomains related to a given domain"
  exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

BIN="${ASSETFINDER_BIN:-assetfinder}"

if ! command -v "$BIN" >/dev/null 2>&1; then
  echo "binary not found: $BIN" >> "$STDERR_FILE"
  exit 127
fi

while read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  "$BIN" --subs-only "$domain" >>"$STDOUT_FILE" 2>>"$STDERR_FILE" || true
done < "$INPUT_FILE"

exit 0
