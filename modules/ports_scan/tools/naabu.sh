#!/bin/bash
# Contrato V2 — $1 input (hosts), $2 stdout, $3 stderr

if [[ "${1:-}" == "--info" ]]; then
    echo "name=naabu"
    echo "version=1.0"
    echo "description=Fast port discovery"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

BIN="${NAABU_BIN:-naabu}"

if ! command -v "$BIN" >/dev/null 2>&1; then
    echo "binary not found: $BIN" >> "$STDERR_FILE"
    exit 127
fi

"$BIN" \
    -list "$INPUT_FILE" \
    -top-ports 1000 \
    -rate 1000 \
    -silent \
    -o "$STDOUT_FILE" \
    >>"$STDERR_FILE" 2>&1 || true

if [[ -s "$STDOUT_FILE" ]]; then
    sort -u -o "$STDOUT_FILE" "$STDOUT_FILE" 2>>"$STDERR_FILE" || true
fi

exit 0
