#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=bac_paths"; echo "version=1.0"; echo "description=Privileged path probe"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
BODY=$(mktemp)
BASES=$(mktemp)
trap 'rm -f "$BODY" "$BASES"' EXIT
PRIV_PATHS=(
  "/admin" "/administrator" "/admin/dashboard" "/api/admin" "/api/internal"
  "/manage" "/console" "/dashboard/admin" "/settings" "/debug"
  "/actuator" "/actuator/env" "/.env" "/server-status"
)
awk '{print $1}' "$IN" | grep -E '^https?://' | sed -E 's|([^/])/[^/]*$|\1|; s|/$||' \
  | sort -u | head -n 8 > "$BASES"
while IFS= read -r base || [[ -n "${base:-}" ]]; do
  [[ -z "${base// }" || "$base" != http* ]] && continue
  for path in "${PRIV_PATHS[@]}"; do
    test_url="${base}${path}"
    code=$(timeout --foreground --signal=KILL 6 curl -s -o "$BODY" -w "%{http_code}" \
      --connect-timeout 3 -L "$test_url" 2>>"$ERR" || echo "000")
    if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" ]]; then
      size=$(wc -c < "$BODY" 2>/dev/null | tr -d ' ' || echo 0)
      if [[ "${size:-0}" -gt 200 ]]; then
        echo "[POSSIBLE-BAC] ${test_url} (HTTP ${code}, size ${size})" >>"$OUT"
      fi
    fi
  done
done < "$BASES"
sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
