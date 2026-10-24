#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=xnlinkfinder"; echo "version=1.1"; echo "description=xnLinkFinder"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
command -v xnLinkFinder >/dev/null 2>&1 || { echo "xnLinkFinder missing" >>"$ERR"; exit 127; }
SCOPE="${TARGET_DOMAIN:-}"
[[ -z "$SCOPE" ]] && SCOPE=$(awk '{print $1}' "$IN" | head -1 | sed -E 's|^https?://||;s|/.*||')
SCOPE=$(echo "$SCOPE" | sed -E 's|^https?://||;s|/.*||')
URLS=$(mktemp); RAW=$(mktemp)
trap 'rm -f "$URLS" "$RAW"' EXIT
MAX="${JS_MAX_URLS:-150}"
awk '{print $1}' "$IN" | grep -E '^https?://' | grep -iE '\.js(\?|$)' | sort -u | head -n "$MAX" > "$URLS"
[[ -s "$URLS" ]] || exit 0
timeout --foreground --signal=KILL "${JS_XN_TIMEOUT:-300}" \
  xnLinkFinder -i "$URLS" -o "$RAW" -sf "$SCOPE" -d 1 -nb -t 8 \
  >>"$ERR" 2>&1 || true
if [[ -f "$RAW" && -s "$RAW" ]]; then
  grep -E 'https?://|^/' "$RAW" 2>/dev/null | sort -u >>"$OUT" || true
fi
[[ -f output.txt ]] && grep -E 'https?://|^/' output.txt 2>/dev/null | sort -u >>"$OUT" || true
rm -f output.txt 2>/dev/null || true
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
