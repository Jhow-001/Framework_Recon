#!/bin/bash
# Contrato V2: $1 input | $2 stdout | $3 stderr
# Imagens: SCREENSHOTS_DIR (export no ambiente do run)

if [[ "${1:-}" == "--info" ]]; then
    echo "name=aquatone"
    echo "version=1.0"
    echo "description=Screenshots via aquatone"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

: > "$STDOUT_FILE"

if ! command -v aquatone >/dev/null 2>&1; then
    echo "aquatone not found" >>"$STDERR_FILE"
    exit 127
fi

OUT_DIR="${SCREENSHOTS_DIR:-${PWD}/aquatone_out}"
mkdir -p "$OUT_DIR"

URLS=$(mktemp)
trap 'rm -f "$URLS"' EXIT

awk '{print $1}' "$INPUT_FILE" | grep -E '^https?://' | sort -u > "$URLS"
[[ -s "$URLS" ]] || exit 0

export CHROME_PATH="${CHROME_PATH:-$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)}"

cat "$URLS" | aquatone \
    -out "$OUT_DIR" \
    -threads "${SCREENSHOT_THREADS:-2}" \
    -screenshot-timeout 30000 \
    >>"$STDERR_FILE" 2>&1 || true

{
    cat "$URLS"
    find "$OUT_DIR" -type f \( -name '*.png' -o -name '*.jpeg' -o -name '*.jpg' \) 2>/dev/null
} | sort -u >>"$STDOUT_FILE"

exit 0
