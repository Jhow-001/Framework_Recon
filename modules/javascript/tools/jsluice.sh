#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=jsluice"; echo "version=1.0"; echo "description=jsluice URLs from JS"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v jsluice >/dev/null 2>&1 || { echo "jsluice missing" >>"$ERR"; exit 127; }
TMP=$(mktemp)
JSBODY=$(mktemp)
URLS=$(mktemp)
trap 'rm -f "$TMP" "$JSBODY" "$URLS"' EXIT

awk '{print $1}' "$IN" | grep -E '^https?://' | grep -iE '\.js(\?|$)' \
  | sort -u | head -n 20 > "$URLS"
[[ -s "$URLS" ]] || exit 0

while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  : > "$JSBODY"
  timeout --foreground --signal=KILL 12 curl -sL -A "Mozilla/5.0" "$url" -o "$JSBODY" 2>>"$ERR" || continue
  [[ -s "$JSBODY" ]] || continue
  # -R resolve relative paths; -u unique
  base=$(echo "$url" | sed -E 's|([^/])/[^/?]*(\?.*)?$|\1|')
  jsluice urls -u -R "$base" "$JSBODY" 2>>"$ERR" \
    | jq -r 'if type=="object" then (.url // .value // empty) else empty end' 2>>"$ERR" >>"$TMP" || true
  # fallback: linhas plain se não for JSON
  if [[ ! -s "$TMP" ]]; then
    jsluice urls -u -R "$base" "$JSBODY" 2>>"$ERR" | grep -E 'https?://|^/' >>"$TMP" || true
  fi
done < "$URLS"

sed 's|^//|https://|' "$TMP" \
  | grep -E '^(https?://|/)' \
  | sort -u >>"$OUT" || true
exit 0
