#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=s3scanner"; echo "version=1.0"; echo "description=Scan S3 bucket candidates"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"

if ! command -v s3scanner >/dev/null 2>&1; then
  echo "s3scanner not found" >>"$ERR"
  exit 127
fi

CAND=$(mktemp)
RAW=$(mktemp)
trap 'rm -f "$CAND" "$RAW"' EXIT

while IFS= read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  base=$(echo "$domain" | cut -d'.' -f1)
  for s in "" "-backup" "-dev" "-staging" "-prod" "-assets" "-media" "-static" "-data"; do
    echo "${base}${s}"
  done
done < "$IN" | sort -u > "$CAND"

[[ -s "$CAND" ]] || exit 0

s3scanner -bucket-file "$CAND" -threads 5 >"$RAW" 2>>"$ERR" || true

while IFS= read -r line || [[ -n "${line:-}" ]]; do
  [[ -z "$line" ]] && continue
  echo "$line" | grep -qi 'not_exist' && continue
  b=$(echo "$line" | grep -oE '[a-z0-9][a-z0-9.-]{2,62}' | head -1)
  if [[ -n "$b" ]]; then
    echo "https://${b}.s3.amazonaws.com" >>"$OUT"
  fi
  echo "$line" >>"$OUT"
done < "$RAW"

sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
