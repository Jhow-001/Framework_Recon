#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_trufflehog"; echo "version=1.0"; echo "description=Keep trufflehog-like findings"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
grep -iE 'trufflehog|verified|DetectorName|Raw:|AWS|Slack|private.?key' "$IN" 2>>"$ERR" \
  | sort -u >>"$OUT" || true
exit 0
