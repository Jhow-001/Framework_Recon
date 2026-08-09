#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=xnlinkfinder"; echo "version=1.0"; echo "description=xnLinkFinder"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
# Preferir entry point pip
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
command -v xnLinkFinder >/dev/null 2>&1 || { echo "xnLinkFinder missing" >>"$ERR"; exit 127; }

SCOPE="${TARGET_DOMAIN:-}"
[[ -z "$SCOPE" ]] && SCOPE=$(awk '{print $1}' "$IN" | head -1 | sed -E 's|^https?://||;s|/.*||')
# -sf exige domínio SEM schema
SCOPE=$(echo "$SCOPE" | sed -E 's|^https?://||;s|/.*||')

URLS=$(mktemp)
RAW=$(mktemp)
trap 'rm -f "$URLS" "$RAW"' EXIT

awk '{print $1}' "$IN" | grep -E '^https?://' | grep -iE '\.js(\?|$)' | sort -u | head -n 10 > "$URLS"
[[ -s "$URLS" ]] || exit 0

# -sf obrigatório na v8.2; -o arquivo; -nb sem banner
timeout --foreground --signal=KILL 60 \
  xnLinkFinder -i "$URLS" -o "$RAW" -sf "$SCOPE" -d 1 -nb -t 8 \
  >>"$ERR" 2>&1 || true

if [[ -f "$RAW" && -s "$RAW" ]]; then
  grep -E 'https?://|^/' "$RAW" 2>/dev/null | sort -u >>"$OUT" || true
elif [[ -d "$RAW" ]]; then
  find "$RAW" -type f -exec cat {} + 2>/dev/null | grep -E 'https?://|^/' | sort -u >>"$OUT" || true
fi
# Também captura stdout estilo cli se gerou output.txt no cwd
[[ -f output.txt ]] && grep -E 'https?://|^/' output.txt 2>/dev/null | sort -u >>"$OUT" || true
sort -u -o "$OUT" "$OUT" 2>/dev/null || true
exit 0
