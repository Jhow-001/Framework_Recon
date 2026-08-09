#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=bola_api"; echo "version=1.0"; echo "description=BOLA-style object id swap"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
CAND=$(mktemp)
BODY=$(mktemp)
trap 'rm -f "$CAND" "$BODY"' EXIT

grep -Ei '/api/|/v[0-9]/|/users/|/orders/|/accounts/|/documents/|/files/|/invoices/' "$IN" 2>>"$ERR" \
  | awk '{print $1}' | sort -u > "$CAND" || true
[[ -s "$CAND" ]] || exit 0

while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  obj_id=$(echo "$url" | grep -Eo '/[0-9]{1,10}(/|$)|/[0-9a-fA-F-]{8,36}(/|$)' | tr -d '/' | head -1)
  [[ -z "$obj_id" ]] && continue
  for test_id in 1 2 999 1001; do
    test_url=$(echo "$url" | sed "s/${obj_id}/${test_id}/")
    code=$(curl -s -o "$BODY" -w "%{http_code}" --connect-timeout 5 --max-time 8 \
      -H "Accept: application/json" "$test_url" 2>>"$ERR" || echo "000")
    size=$(wc -c < "$BODY" 2>/dev/null | tr -d ' ' || echo 0)
    if [[ "$code" == "200" && "${size:-0}" -gt 50 ]]; then
      if grep -qE '\{|\[|"id"|"user"|"email"' "$BODY" 2>/dev/null; then
        echo "[POSSIBLE-BOLA] ${url} → ${test_url} (HTTP ${code})" >>"$OUT"
      fi
    fi
  done
done < "$CAND"

sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
