#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=gau_js"; echo "version=1.0"; echo "description=Historical JS via gau or crawling dump"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
export PATH="${HOME}/go/bin:${PATH}"
awk '{print $1}' "$IN" 2>/dev/null | grep -Ei '\.js(\?|$)' | sort -u >> "$OUT" || true
DOMAIN="${TARGET_DOMAIN:-}"
GAU_DUMP=""
for p in \
  "${ROOT_DIR:-}/results/${DOMAIN}/crawling/tools/gau/result.txt" \
  "${RESULTS_DIR:-}/crawling/tools/gau/result.txt"
do
  [[ -s "$p" ]] && { GAU_DUMP="$p"; break; }
done
if [[ -n "$GAU_DUMP" ]]; then
  grep -Ei '\.js(\?|$)' "$GAU_DUMP" >> "$OUT" || true
elif command -v gau >/dev/null 2>&1 && [[ -n "$DOMAIN" ]]; then
  timeout --foreground --signal=KILL 180 gau --subs "$DOMAIN" 2>>"$ERR" \
    | grep -Ei '\.js(\?|$)' >> "$OUT" || true
else
  echo "gau missing and no crawling dump" >>"$ERR"
fi
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
