#!/bin/bash
# Contrato V2 — input: linhas httpx (URL na 1ª coluna) ou URLs puras

if [[ "${1:-}" == "--info" ]]; then
    echo "name=wafw00f"
    echo "version=1.0"
    echo "description=Detect WAF with wafw00f"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

: > "$STDOUT_FILE"

if ! command -v wafw00f >/dev/null 2>&1; then
    echo "wafw00f not found" >>"$STDERR_FILE"
    exit 127
fi

CLEAN=$(mktemp)
trap 'rm -f "$CLEAN"' EXIT

# Extrai só URL (httpx: "https://x [200] [title]")
awk '{print $1}' "$INPUT_FILE" \
  | grep -E '^https?://' \
  | sort -u > "$CLEAN" || true

# Fallback: linha inteira se já for URL
if [[ ! -s "$CLEAN" ]]; then
    grep -E '^https?://' "$INPUT_FILE" | sort -u > "$CLEAN" || true
fi

[[ -s "$CLEAN" ]] || exit 0

# Tentativa em lote
wafw00f -a -i "$CLEAN" -o "$STDOUT_FILE" --no-colors >>"$STDERR_FILE" 2>&1 || true

# Fallback URL a URL se lote vazio
if [[ ! -s "$STDOUT_FILE" ]]; then
    while IFS= read -r url || [[ -n "${url:-}" ]]; do
        [[ -z "${url// }" ]] && continue
        {
            echo "=== ${url} ==="
            wafw00f -a --no-colors "$url" 2>>"$STDERR_FILE" || true
            echo
        } >>"$STDOUT_FILE"
    done < "$CLEAN"
fi

exit 0
