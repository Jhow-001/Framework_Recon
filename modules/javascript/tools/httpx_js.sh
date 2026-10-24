#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=httpx_js"; echo "version=1.0"; echo "description=Keep live JS URLs"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
URLS=$(mktemp)
trap 'rm -f "$URLS"' EXIT
awk '{print $1}' "$IN" 2>/dev/null | grep -E '^https?://' | grep -Ei '\.js(\?|$)' | sort -u > "$URLS"
[[ -s "$URLS" ]] || exit 0
BIN="${HTTPX_BIN:-}"
if [[ -z "$BIN" ]]; then
  for c in "${HOME}/go/bin/httpx" "$(command -v httpx 2>/dev/null)"; do
    [[ -n "$c" && -x "$c" ]] && BIN="$c" && break
  done
fi
if [[ -z "$BIN" ]]; then
  echo "httpx missing — passing all JS URLs" >>"$ERR"
  cat "$URLS" > "$OUT"
  exit 0
fi
timeout --foreground --signal=KILL 300 \
  "$BIN" -l "$URLS" -mc 200 -silent -timeout 10 -o "$OUT" >>"$ERR" 2>&1 || true
if [[ ! -s "$OUT" ]]; then
  cat "$URLS" > "$OUT"
fi
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
