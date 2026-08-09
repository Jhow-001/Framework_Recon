#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=nuclei_exposure"; echo "version=1.0"; echo "description=Nuclei exposure/misconfig tags"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v nuclei >/dev/null 2>&1 || { echo "nuclei missing" >>"$ERR"; exit 127; }

URLS=$(mktemp)
trap 'rm -f "$URLS"' EXIT
awk '{print $1}' "$IN" | grep -E '^https?://' | sort -u > "$URLS"
[[ -s "$URLS" ]] || exit 0

nuclei -l "$URLS" \
  -tags exposure,misconfiguration,default-login,token \
  -c 25 -timeout 10 -retries 1 -silent \
  -o "$OUT" >>"$ERR" 2>&1 || true
exit 0
