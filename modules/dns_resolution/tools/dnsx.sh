#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
    echo "name=dnsx"
    echo "version=1.0"
    echo "description=DNS resolution with dnsx"
    exit 0
fi
INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"
BIN="${DNSX_BIN:-dnsx}"
if ! command -v "$BIN" >/dev/null 2>&1; then
    echo "binary not found: $BIN" >> "$STDERR_FILE"
    exit 127
fi
LIMIT="${DNS_MAX_HOSTS:-8000}"
LIMITED=$(mktemp)
trap 'rm -f "$LIMITED"' EXIT
sort -u "$INPUT_FILE" 2>/dev/null | head -n "$LIMIT" > "$LIMITED"
[[ -s "$LIMITED" ]] || exit 0

# Sem -o: stdout linha a linha → sobrevive a KILL/timeout
if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL "$BIN" -l "$LIMITED" -silent 2>>"$STDERR_FILE" | stdbuf -oL tee -a "$STDOUT_FILE" >/dev/null || true
else
  "$BIN" -l "$LIMITED" -silent 2>>"$STDERR_FILE" >>"$STDOUT_FILE" || true
fi
exit 0
