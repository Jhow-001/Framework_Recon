#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_slack"; echo "version=1.0"; echo "description=Slack token pattern lines"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
grep -E 'xox[baprs]-[0-9A-Za-z-]{10,}' "$IN" 2>>"$ERR" | sort -u >>"$OUT" || true
exit 0
