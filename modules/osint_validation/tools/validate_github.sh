#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_github"; echo "version=1.0"; echo "description=Validate GitHub URLs"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
while IFS= read -r line || [[ -n "${line:-}" ]]; do
  [[ -z "${line// }" ]] && continue
  echo "$line" | grep -qiE 'github\.com|gist\.github' || continue
  url=$(echo "$line" | grep -oE 'https?://[^[:space:]]+' | head -1)
  [[ -z "$url" ]] && url="$line"
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 15 \
    ${TOKEN:+-H "Authorization: Bearer $TOKEN"} "$url" 2>>"$ERR" || echo "000")
  if [[ "$code" =~ ^2|3 ]]; then
    echo "${url} [http=${code}]" >>"$OUT"
  fi
done < "$IN"
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
