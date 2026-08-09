#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=nuclei_access"; echo "version=1.0"; echo "description=Nuclei access-control tags"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v nuclei >/dev/null 2>&1 || { echo "nuclei missing" >>"$ERR"; exit 127; }
URLS=$(mktemp)
trap 'rm -f "$URLS"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' | sort -u | head -n 30 > "$URLS"
[[ -s "$URLS" ]] || exit 0
nuclei -l "$URLS" \
  -tags idor,bola,auth-bypass,broken-access,default-login \
  -c 15 -timeout 8 -retries 1 -silent \
  -o "$OUT" >>"$ERR" 2>&1 || true
exit 0
