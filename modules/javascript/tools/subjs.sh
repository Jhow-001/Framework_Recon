#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=subjs"; echo "version=1.0"; echo "description=JS URLs via subjs"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
export PATH="${HOME}/go/bin:${PATH}"
awk '{print $1}' "$IN" 2>/dev/null | grep -Ei '\.js(\?|$)' | sort -u >> "$OUT" || true
command -v subjs >/dev/null 2>&1 || { echo "subjs missing" >>"$ERR"; sort -u -o "$OUT" "$OUT"; exit 0; }
DOMAIN="${TARGET_DOMAIN:-}"
[[ -z "$DOMAIN" ]] && exit 0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
printf 'https://%s\n' "$DOMAIN" | timeout --foreground --signal=KILL 90 subjs >"$TMP" 2>>"$ERR" || true
[[ -s "$TMP" ]] && cat "$TMP" >> "$OUT" || true
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
