#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=gau"; echo "version=1.0"; echo "description=GetAllURLs"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
command -v gau >/dev/null 2>&1 || { echo "gau missing" >>"$ERR"; exit 127; }
HOSTS=$(mktemp)
trap 'rm -f "$HOSTS"' EXIT
awk '{print $1}' "$IN" \
  | sed -E 's|^https?://||;s|/.*||;s|:.*||' \
  | tr '[:upper:]' '[:lower:]' | sort -u | head -n 15 > "$HOSTS"
while IFS= read -r host || [[ -n "${host:-}" ]]; do
  [[ -z "${host// }" ]] && continue
  timeout --foreground --signal=KILL 20 gau --blacklist png,jpg,gif,css,woff,woff2,svg "$host" 2>>"$ERR" || true
done < "$HOSTS" | sort -u >>"$OUT" || true
exit 0
