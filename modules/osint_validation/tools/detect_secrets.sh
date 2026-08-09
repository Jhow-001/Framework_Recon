#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=detect_secrets"; echo "version=1.0"; echo "description=detect-secrets scan on text input"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
if ! command -v detect-secrets >/dev/null 2>&1; then
  echo "detect-secrets not installed" >>"$ERR"
  exit 0
fi
# scan arquivo de texto do osint
detect-secrets scan --force-use-all-plugins "$IN" 2>>"$ERR" \
  | jq -r '.results | to_entries[] | .key as $f | .value[] | "\($f):\(.line_number // 0):\(.type // "secret")"' \
  2>>"$ERR" >>"$OUT" || true
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
