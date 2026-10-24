#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=getjs"; echo "version=1.0"; echo "description=Live JS URLs via getJS"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
export PATH="${HOME}/go/bin:${HOME}/.local/bin:/usr/local/bin:${PATH}"
awk '{print $1}' "$IN" 2>/dev/null | grep -Ei '\.js(\?|$)' | sort -u >> "$OUT" || true
command -v getJS >/dev/null 2>&1 || { echo "getJS missing" >>"$ERR"; sort -u -o "$OUT" "$OUT"; exit 0; }
DOMAIN="${TARGET_DOMAIN:-}"
[[ -z "$DOMAIN" ]] && DOMAIN=$(awk '{print $1}' "$IN" | head -1 | sed -E 's|^https?://||;s|/.*||')
[[ -z "$DOMAIN" ]] && exit 0
BASE="https://${DOMAIN}"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
timeout --foreground --signal=KILL 120 getJS -url "$BASE" -complete -output "$TMP" >>"$ERR" 2>&1 || true
[[ -s "$TMP" ]] && grep -Ei '\.js(\?|$)|https?://' "$TMP" >> "$OUT" || true
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
