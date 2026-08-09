#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_gitdumper"; echo "version=1.0"; echo "description=Re-check exposed .git/.env"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
while IFS= read -r line || [[ -n "${line:-}" ]]; do
  [[ -z "${line// }" ]] && continue
  echo "$line" | grep -qiE '\.git|\.env' || continue
  url=$(echo "$line" | awk '{print $1}')
  [[ "$url" != http* ]] && continue
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>>"$ERR" || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "${url} [confirmed=${code}]" >>"$OUT"
  fi
done < "$IN"
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
