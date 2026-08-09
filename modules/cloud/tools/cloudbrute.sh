#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=cloudbrute"; echo "version=1.0"; echo "description=Cloudbrute storage enum"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v cloudbrute >/dev/null 2>&1 || { echo "cloudbrute not found" >>"$ERR"; exit 127; }
ROOT="${ROOT_DIR:-}"
WL="${CLOUD_WORDLIST:-${ROOT}/wordlists/cloud/mutations-2k.txt}"
CFG="${ROOT}/tools/cloudbrute/config"
PROVIDERS="${CLOUD_PROVIDERS:-amazon}"
[[ -f "$WL" && -d "$CFG" ]] || { echo "wordlist or config missing" >>"$ERR"; exit 0; }
# 1 domínio principal
domain=$(awk '{print $1}' "$IN" | head -1 | sed -E 's|^https?://||;s|/.*||')
[[ -z "$domain" ]] && domain="${TARGET_DOMAIN:-}"
[[ -z "$domain" ]] && exit 0
base=$(echo "$domain" | cut -d'.' -f1)
for prov in $PROVIDERS; do
  tmp=$(mktemp)
  timeout --foreground --signal=KILL 120 cloudbrute -d "$domain" -k "$base" -w "$WL" -t 15 -m storage \
    -c "$prov" -C "$CFG" -o "$tmp" >>"$ERR" 2>&1 || true
  [[ -s "$tmp" ]] && cat "$tmp" >>"$OUT"
  rm -f "$tmp"
done
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
