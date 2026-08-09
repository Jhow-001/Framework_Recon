#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=ffuf"; echo "version=1.0"; echo "description=Directory fuzz"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v ffuf >/dev/null 2>&1 || { echo "ffuf missing" >>"$ERR"; exit 127; }
WL="${FUZZ_WORDLIST:-${ROOT_DIR}/wordlists/paths/common.txt}"
[[ -f "$WL" ]] || WL="/usr/share/wordlists/dirb/common.txt"
[[ -f "$WL" ]] || WL="/usr/share/seclists/Discovery/Web-Content/common.txt"
[[ -f "$WL" ]] || { echo "wordlist missing" >>"$ERR"; exit 0; }
MAX_URLS="${FUZZ_MAX_URLS:-15}"
THREADS="${FUZZ_THREADS:-15}"
RATE="${FUZZ_RATE:-25}"
TIME_PER_URL="${FUZZ_TIME_PER_URL:-90}"
URLS=$(mktemp)
TMP=$(mktemp)
trap 'rm -f "$URLS" "$TMP"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' | sort -u | head -n "$MAX_URLS" > "$URLS"
[[ -s "$URLS" ]] || exit 0
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  base="${url%/}"
  timeout "$TIME_PER_URL" ffuf -u "${base}/FUZZ" -w "$WL" \
    -mc 200,201,202,204,301,302,307,401,403 \
    -t "$THREADS" -rate "$RATE" -s \
    -o "$TMP" -of json >>"$ERR" 2>&1 || true
  if [[ -s "$TMP" ]]; then
    jq -r '.results[]?.url // empty' "$TMP" 2>>"$ERR" >>"$OUT" || true
  fi
  : > "$TMP"
done < "$URLS"
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
