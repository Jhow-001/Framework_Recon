#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=ffuf_sensitive"; echo "version=1.0"; echo "description=Sensitive file fuzz"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v ffuf >/dev/null 2>&1 || { echo "ffuf missing" >>"$ERR"; exit 127; }

WL="${EXPOSURE_SENSITIVE_WL:-${ROOT_DIR}/wordlists/exposure/sensitive_files.txt}"
[[ -f "$WL" ]] || WL="/usr/share/seclists/Discovery/Web-Content/Common-DB-Backups.txt"
[[ -f "$WL" ]] || { echo "sensitive wordlist missing" >>"$ERR"; exit 0; }

URLS=$(mktemp)
TMP=$(mktemp)
trap 'rm -f "$URLS" "$TMP"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' | sort -u > "$URLS"

while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  url="${url%/}"
  ffuf -u "${url}/FUZZ" -w "$WL" \
    -mc 200,201,204,301,302,401,403 -t 15 -rate 20 -s \
    -o "$TMP" -of json >>"$ERR" 2>&1 || true
  if [[ -s "$TMP" ]]; then
    jq -r '.results[]?.url // empty' "$TMP" 2>>"$ERR" >>"$OUT" || true
  fi
  : > "$TMP"
done < "$URLS"

sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
