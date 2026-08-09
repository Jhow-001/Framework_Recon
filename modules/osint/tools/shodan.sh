#!/bin/bash
# Contrato V2 — $1 input, $2 stdout, $3 stderr
if [[ "${1:-}" == "--info" ]]; then
  echo "name=shodan"
  echo "version=1.0"
  echo "description=Shodan domain/host intel (API)"
  exit 0
fi

IN="${1:-}"
OUT="${2:-}"
ERR="${3:-}"
: > "$OUT"

KEY="${SHODAN_API_KEY:-}"
if [[ -z "$KEY" && -n "${ROOT_DIR:-}" && -f "${ROOT_DIR}/config/api_keys.conf" ]]; then
  KEY=$(grep -E '^SHODAN_API_KEY=' "${ROOT_DIR}/config/api_keys.conf" 2>/dev/null \
    | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
fi
if [[ -z "$KEY" ]]; then
  echo "SHODAN_API_KEY missing" >>"$ERR"
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "curl missing" >>"$ERR"; exit 127; }

DOMAIN="${TARGET_DOMAIN:-}"
if [[ -z "$DOMAIN" && -f "$IN" ]]; then
  DOMAIN=$(head -1 "$IN" | tr -d '[:space:]')
fi
DOMAIN=$(echo "$DOMAIN" | sed -E 's|^https?://||; s|/.*||; s|^\*\.||')
[[ -n "$DOMAIN" ]] || { echo "no domain" >>"$ERR"; exit 0; }

TMP=$(mktemp)
TMP2=$(mktemp)
trap 'rm -f "$TMP" "$TMP2"' EXIT

# 1) DNS domain
code=$(curl -sS -o "$TMP" -w "%{http_code}" --max-time 25 \
  "https://api.shodan.io/dns/domain/${DOMAIN}?key=${KEY}" 2>>"$ERR" || echo "000")

if [[ "$code" == "200" && -s "$TMP" ]] && command -v jq >/dev/null 2>&1; then
  jq -r --arg d "$DOMAIN" '
    ((.subdomains // [])[]? | "\(.)\($d)"),
    ((.data // [])[]? | select(.subdomain != null) | "\(.subdomain).\($d)"),
    ((.data // [])[]? | select(.type=="A" or .type=="AAAA") | .value // empty)
  ' "$TMP" 2>>"$ERR" | sed '/^$/d' | sort -u >>"$OUT" || true
else
  echo "shodan dns/domain HTTP $code" >>"$ERR"
fi

# 2) Host search
code2=$(curl -sS -o "$TMP2" -w "%{http_code}" --max-time 30 \
  --get "https://api.shodan.io/shodan/host/search" \
  --data-urlencode "key=${KEY}" \
  --data-urlencode "query=hostname:${DOMAIN}" \
  --data-urlencode "minify=true" 2>>"$ERR" || echo "000")

if [[ "$code2" == "200" && -s "$TMP2" ]] && command -v jq >/dev/null 2>&1; then
  jq -r '
    .matches[]? |
    ( (.ip_str // empty) ),
    ( (.hostnames // [])[]? ),
    ( if (.ip_str != null and .ports != null)
      then "\(.ip_str):ports:\(.ports|map(tostring)|join(","))"
      else empty end )
  ' "$TMP2" 2>>"$ERR" | sed '/^$/d' | sort -u >>"$OUT" || true
else
  echo "shodan host/search HTTP ${code2:-na}" >>"$ERR"
fi

sort -u -o "$OUT" "$OUT" 2>>"$ERR" || true
exit 0
