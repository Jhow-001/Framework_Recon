#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_aws"; echo "version=1.0"; echo "description=AWS key pattern lines"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
grep -E 'AKIA[0-9A-Z]{16}|aws_secret_access_key|ASIA[0-9A-Z]{16}' "$IN" 2>>"$ERR" \
  | sort -u >>"$OUT" || true
exit 0
