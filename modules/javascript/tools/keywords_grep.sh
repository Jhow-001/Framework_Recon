#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=keywords_grep"; echo "version=1.1"; echo "description=JS URLs with keyword hits"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
URLS=$(mktemp); BODY=$(mktemp)
trap 'rm -f "$URLS" "$BODY"' EXIT
MAX="${JS_MAX_URLS:-80}"
awk '{print $1}' "$IN" | grep -E '^https?://' | grep -iE '\.js(\?|$)' | sort -u | head -n "$MAX" > "$URLS"
[[ -s "$URLS" ]] || exit 0
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  : > "$BODY"
  timeout --foreground --signal=KILL 12 curl -skL "$url" -o "$BODY" 2>>"$ERR" || continue
  [[ -s "$BODY" ]] || continue
  hits=$(grep -InoE 'api[_-]?key|secret|password|token|bearer|authorization|aws_access|private_key|graphql|/api/|/admin|apikey' "$BODY" 2>/dev/null | head -n 20 || true)
  [[ -z "$hits" ]] && continue
  echo "$url" >> "$OUT"
  printf '%s\n' "$hits" | sed "s|^|${url}\t|" >> "$ERR"
done < "$URLS"
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
