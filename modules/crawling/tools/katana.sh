#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=katana"; echo "version=1.0"; echo "description=Active crawl"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v katana >/dev/null 2>&1 || { echo "katana missing" >>"$ERR"; exit 127; }

URLS=$(mktemp)
trap 'rm -f "$URLS"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' | sort -u > "$URLS"
[[ -s "$URLS" ]] || exit 0

katana -list "$URLS" -d 1 -c 2 -rl 10 -silent 2>>"$ERR" | sort -u >>"$OUT" || true
exit 0
