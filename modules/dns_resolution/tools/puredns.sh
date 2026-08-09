#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
    echo "name=puredns"
    echo "version=1.0"
    echo "description=DNS resolution with puredns"
    exit 0
fi
INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"
BIN="${PUREDNS_BIN:-puredns}"
RESOLVERS_FILE="${RESOLVERS:-${ROOT_DIR}/config/resolvers.txt}"
if ! command -v "$BIN" >/dev/null 2>&1; then
    echo "binary not found: $BIN" >> "$STDERR_FILE"
    exit 127
fi
if [[ ! -f "$RESOLVERS_FILE" ]]; then
    echo "resolvers not found: $RESOLVERS_FILE" >> "$STDERR_FILE"
    exit 0
fi
LIMIT="${DNS_MAX_HOSTS:-8000}"
LIMITED=$(mktemp)
trap 'rm -f "$LIMITED"' EXIT
sort -u "$INPUT_FILE" 2>/dev/null | head -n "$LIMIT" > "$LIMITED"
[[ -s "$LIMITED" ]] || exit 0
# resolve escreve em stdout → redirecionado para STDOUT_FILE (parcial no timeout)
"$BIN" resolve "$LIMITED" -r "$RESOLVERS_FILE" >>"$STDOUT_FILE" 2>>"$STDERR_FILE" || true
exit 0
