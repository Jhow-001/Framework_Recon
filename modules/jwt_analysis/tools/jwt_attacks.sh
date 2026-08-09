#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=jwt_attacks"; echo "version=1.0"; echo "description=jwt_tool basic checks"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"

BIN=""
command -v jwt_tool >/dev/null 2>&1 && BIN=jwt_tool
command -v jwt-tool >/dev/null 2>&1 && BIN=jwt-tool
[[ -z "$BIN" ]] && { echo "jwt_tool missing" >>"$ERR"; exit 0; }

grep -Eo 'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*' "$IN" 2>>"$ERR" | sort -u | while IFS= read -r jwt; do
  echo "=== JWT ${jwt:0:40}... ===" >>"$OUT"
  "$BIN" "$jwt" -TAM >>"$OUT" 2>>"$ERR" || true
  for secret in secret password 123456 jwt key admin changeme; do
    if "$BIN" "$jwt" -C -d "$secret" 2>>"$ERR" | grep -qiE 'valid|signature|success'; then
      echo "[WEAK-SECRET] $secret" >>"$OUT"
    fi
  done
  echo >>"$OUT"
done
exit 0
