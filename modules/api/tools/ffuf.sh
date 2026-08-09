#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=ffuf"; echo "version=1.0"; echo "description=API path/method/param fuzz"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v ffuf >/dev/null 2>&1 || { echo "ffuf missing" >>"$ERR"; exit 127; }
PARAM_WL="${API_PARAM_WL:-${ROOT_DIR}/wordlists/parameters/params.txt}"
API_WL="${API_ENDPOINT_WL:-${ROOT_DIR}/wordlists/paths/api-endpoints.txt}"
[[ -f "$PARAM_WL" ]] || PARAM_WL="/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt"
[[ -f "$API_WL" ]] || API_WL="${ROOT_DIR}/wordlists/paths/common.txt"
[[ -f "$API_WL" ]] || API_WL="/usr/share/seclists/Discovery/Web-Content/common.txt"
URLS=$(mktemp)
J=$(mktemp)
trap 'rm -f "$URLS" "$J"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' \
  | grep -viE '\.(css|js|map|png|jpg|gif|svg|ico|woff2?)(\?|$)' \
  | sort -u | head -n 5 > "$URLS"
[[ -s "$URLS" ]] || exit 0
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  base="${url%/}"
  if [[ -f "$API_WL" ]]; then
    timeout --foreground --signal=KILL 60 ffuf -u "${base}/FUZZ" -w "$API_WL" \
      -mc 200,201,202,204,301,302,401,403,405 -t 10 -rate 20 -s \
      -o "$J" -of json >>"$ERR" 2>&1 || true
    jq -r '.results[]?.url // empty' "$J" 2>>"$ERR" >>"$OUT" || true
    : > "$J"
  fi
  for method in OPTIONS PUT PATCH DELETE; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" --max-time 6 "$base" 2>>"$ERR" || echo 000)
    if [[ "$code" =~ ^(200|201|204|401|403|405)$ ]]; then
      echo "${method} ${base} [${code}]" >>"$OUT"
    fi
  done
  if [[ -f "$PARAM_WL" ]]; then
    # wordlist menor para params
    PARAM_SMALL=$(mktemp)
    head -n 150 "$PARAM_WL" > "$PARAM_SMALL"
    timeout --foreground --signal=KILL 60 ffuf -u "${base}?FUZZ=test" -w "$PARAM_SMALL" \
      -mc 200,301,302,400,401,403,500 -t 10 -rate 20 -s \
      -o "$J" -of json >>"$ERR" 2>&1 || true
    jq -r '.results[]?.url // empty' "$J" 2>>"$ERR" >>"$OUT" || true
    rm -f "$PARAM_SMALL"
    : > "$J"
  fi
done < "$URLS"
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
