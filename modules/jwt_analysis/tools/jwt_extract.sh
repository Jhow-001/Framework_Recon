#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=jwt_extract"; echo "version=1.0"; echo "description=Find JWTs in input/headers"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
JWT_REGEX='eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*'
RAW=$(mktemp)
trap 'rm -f "$RAW"' EXIT

while IFS= read -r line || [[ -n "${line:-}" ]]; do
  [[ -z "${line// }" ]] && continue
  echo "$line" | grep -Eo "$JWT_REGEX" >>"$RAW" 2>/dev/null || true
  url=$(echo "$line" | awk '{print $1}')
  if [[ "$url" == http* ]]; then
    headers=$(curl -s -D - -o /dev/null --connect-timeout 5 --max-time 8 "$url" 2>>"$ERR" || true)
    echo "$headers" | grep -Eo "$JWT_REGEX" >>"$RAW" 2>/dev/null || true
    echo "$headers" | grep -iE 'authorization:|set-cookie:' >>"$OUT" 2>/dev/null || true
  fi
done < "$IN"

sort -u "$RAW" -o "$RAW"
# stdout prioriza JWTs (para o hybrid alimentar decode/attacks)
cat "$RAW" >>"$OUT"
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
