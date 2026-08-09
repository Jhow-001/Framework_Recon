#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=jwt_decode"; echo "version=1.0"; echo "description=Decode JWT header/payload"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"

jwt_b64decode() {
  local part="$1" pad=$(( (4 - ${#part} % 4) % 4 ))
  part="${part}$(printf '=%.0s' $(seq 1 $pad 2>/dev/null))"
  part=$(echo "$part" | tr '_-' '/+')
  echo "$part" | base64 -d 2>/dev/null || true
}

grep -Eo 'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*' "$IN" 2>>"$ERR" | sort -u | while IFS= read -r jwt; do
  header=$(echo "$jwt" | cut -d. -f1)
  payload=$(echo "$jwt" | cut -d. -f2)
  {
    echo "========== JWT =========="
    echo "TOKEN: ${jwt:0:50}..."
    echo "--- HEADER ---"
    jwt_b64decode "$header"
    echo
    echo "--- PAYLOAD ---"
    jwt_b64decode "$payload"
    echo
  } >>"$OUT"
  decoded=$(jwt_b64decode "$header"; jwt_b64decode "$payload")
  echo "$decoded" | grep -qi '"alg"[[:space:]]*:[[:space:]]*"none"' && echo "[CRITICAL] alg:none" >>"$OUT"
  echo "$decoded" | grep -qiE '"role"[[:space:]]*:[[:space:]]*"(admin|root|superuser)"' && echo "[HIGH] privileged role" >>"$OUT"
  echo "$decoded" | grep -qiE '"admin"[[:space:]]*:[[:space:]]*true' && echo "[HIGH] admin:true" >>"$OUT"
  echo >>"$OUT"
done
exit 0
