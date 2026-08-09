#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=crt"; echo "version=1.0"; echo "description=crt.sh certificate search"; exit 0
fi
INPUT_FILE="$1"; STDOUT_FILE="$2"; STDERR_FILE="$3"
command -v curl >/dev/null 2>&1 || { echo "curl missing" >>"$STDERR_FILE"; exit 127; }
RAW=$(mktemp)
while read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  curl -sG --max-time 60 "https://crt.sh/" \
    --data-urlencode "q=%25.${domain}" \
    --data-urlencode "output=json" >>"$RAW" 2>>"$STDERR_FILE" || true
  echo >>"$RAW"
done < "$INPUT_FILE"
if command -v jq >/dev/null 2>&1; then
  jq -r '.[].name_value // empty' "$RAW" 2>>"$STDERR_FILE"
else
  grep -oE '"name_value"\s*:\s*"[^"]+"' "$RAW" | sed 's/.*"name_value"\s*:\s*"//;s/"$//'
fi 2>>"$STDERR_FILE" \
  | sed 's/\\n/\n/g' | tr -d '\r' | sed 's/^\*\.//' | tr '[:upper:]' '[:lower:]' \
  | grep -E '^[a-z0-9._-]+(\.[a-z0-9._-]+)+$' | sort -u >>"$STDOUT_FILE" || true
rm -f "$RAW"
exit 0
