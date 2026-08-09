#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=base64_mass_decode"; echo "version=1.0"; echo "description=Decode interesting base64 blobs"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"

grep -Eo '[A-Za-z0-9+/]{24,}={0,2}' "$IN" 2>>"$ERR" | sort -u | head -n 200 | while IFS= read -r b64; do
  decoded=$(echo "$b64" | base64 -d 2>/dev/null | tr -cd '[:print:]\n' | head -c 300)
  [[ -z "$decoded" || ${#decoded} -le 4 ]] && continue
  if echo "$decoded" | grep -qiE 'password|secret|key|token|admin|http|AKIA|ghp_|eyJ|\{'; then
    echo "B64:${b64:0:40}... | DECODED:${decoded}" >>"$OUT"
  fi
done
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
