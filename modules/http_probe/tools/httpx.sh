#!/bin/bash
# Contrato V2 — $1 input, $2 stdout, $3 stderr — zero vazamento

if [[ "${1:-}" == "--info" ]]; then
    echo "name=httpx"
    echo "version=1.0"
    echo "description=HTTP probe with ProjectDiscovery httpx"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

# Resolver binário (ProjectDiscovery)
BIN="${HTTPX_BIN:-}"
if [[ -z "$BIN" ]]; then
    for c in \
        "${HOME}/go/bin/httpx" \
        "$(go env GOPATH 2>/dev/null)/bin/httpx" \
        "$(command -v httpx 2>/dev/null)"
    do
        [[ -n "$c" && -x "$c" ]] || continue
        if "$c" -h 2>&1 | grep -q -- '-list\|-l '; then
            BIN="$c"
            break
        fi
    done
fi

if [[ -z "$BIN" ]] || ! command -v "$BIN" >/dev/null 2>&1 && [[ ! -x "$BIN" ]]; then
    echo "binary not found: httpx" >> "$STDERR_FILE"
    exit 127
fi

# -o grava no arquivo; resto de stderr da tool vai para STDERR_FILE
"$BIN" \
    -l "$INPUT_FILE" \
    -silent \
    -status-code \
    -title \
    -tech-detect \
    -follow-redirects \
    -o "$STDOUT_FILE" \
    >>"$STDERR_FILE" 2>&1 || true

# Dedup in-place se o arquivo existir
if [[ -s "$STDOUT_FILE" ]]; then
    sort -u -o "$STDOUT_FILE" "$STDOUT_FILE" 2>>"$STDERR_FILE" || true
fi

exit 0
