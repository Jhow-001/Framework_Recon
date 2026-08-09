#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=idor_scanner"; echo "version=1.0"; echo "description=IDOR id variation probe"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
CAND=$(mktemp)
ORIG=$(mktemp)
TEST=$(mktemp)
trap 'rm -f "$CAND" "$ORIG" "$TEST"' EXIT

grep -Eo 'https?://[^ ]+[?&/]([a-zA-Z_]*id|user|order|account|doc|file|invoice)=?[0-9a-fA-F-]{1,36}' "$IN" 2>>"$ERR" \
  | sort -u > "$CAND" || true
[[ -s "$CAND" ]] || exit 0

while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url// }" ]] && continue
  base_id=$(echo "$url" | grep -Eo '[0-9]{1,10}|[0-9a-fA-F-]{8,36}' | tail -1)
  [[ -z "$base_id" ]] && continue
  for test_id in 1 2 3 100 101 999 1000 "00000000-0000-0000-0000-000000000001"; do
    test_url=$(echo "$url" | sed "s/${base_id}/${test_id}/g")
    [[ "$test_url" == "$url" ]] && continue
    code_orig=$(curl -s -o "$ORIG" -w "%{http_code}" --connect-timeout 5 --max-time 8 "$url" 2>>"$ERR" || echo "000")
    size_orig=$(wc -c < "$ORIG" 2>/dev/null | tr -d ' ' || echo 0)
    code_test=$(curl -s -o "$TEST" -w "%{http_code}" --connect-timeout 5 --max-time 8 "$test_url" 2>>"$ERR" || echo "000")
    size_test=$(wc -c < "$TEST" 2>/dev/null | tr -d ' ' || echo 0)
    if [[ "$code_orig" == "200" && "$code_test" == "200" ]]; then
      diff=$(( size_orig > size_test ? size_orig - size_test : size_test - size_orig ))
      if [[ $diff -lt 500 || ${size_test:-0} -gt 100 ]]; then
        echo "[POSSIBLE-IDOR] ${url} → ${test_url} (HTTP ${code_test}, size ${size_test})" >>"$OUT"
      fi
    fi
  done
done < "$CAND"

sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
