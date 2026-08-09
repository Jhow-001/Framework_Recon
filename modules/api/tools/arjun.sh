#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=arjun"; echo "version=1.0"; echo "description=Hidden parameter discovery"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v arjun >/dev/null 2>&1 || { echo "arjun missing" >>"$ERR"; exit 127; }

WL="${API_PARAM_WL:-${ROOT_DIR}/wordlists/parameters/params.txt}"
[[ -f "$WL" ]] || WL="/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt"
[[ -f "$WL" ]] || WL=""

URLS=$(mktemp)
trap 'rm -f "$URLS"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' \
  | grep -viE '\.(css|js|map|png|jpg|gif|svg|ico|woff2?)(\?|$)' \
  | sort -u | head -40 > "$URLS"
[[ -s "$URLS" ]] || exit 0

while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  TMP=$(mktemp)
  if [[ -n "$WL" ]]; then
    arjun -u "$url" -w "$WL" -t 10 -oT "$TMP" >>"$ERR" 2>&1 || true
  else
    arjun -u "$url" -t 10 -oT "$TMP" >>"$ERR" 2>&1 || true
  fi
  [[ -s "$TMP" ]] && cat "$TMP" >>"$OUT"
  rm -f "$TMP"
done < "$URLS"

sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
