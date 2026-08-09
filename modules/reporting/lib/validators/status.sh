#!/bin/bash
# status.sh — HTTP status + tamanho
validate_status() {
  local raw="$1"
  local url
  url=$(echo "$raw" | grep -oE 'https?://[^[:space:]\"<>]+' | head -1)
  if [[ -z "$url" ]]; then
    if echo "$raw" | grep -qE '^[a-zA-Z0-9._-]+:[0-9]+'; then
      url="https://${raw%% *}"
    elif echo "$raw" | grep -qE '^[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}'; then
      url="https://${raw%% *}"
    else
      echo "0|0||no_url"
      return 0
    fi
  fi
  url=$(echo "$url" | sed 's/[),;]$//')
  local tmp code err=""
  tmp=$(mktemp)
  code=$(curl -sS -L --max-redirs 3 \
    -A "Mozilla/5.0 (compatible; ReconFramework/2.0)" \
    --connect-timeout 5 --max-time 10 \
    -o "$tmp" -w "%{http_code}|%{size_download}|%{url_effective}" \
    "$url" 2>/dev/null) || err="curl_fail"
  if [[ -z "$code" ]]; then
    rm -f "$tmp"
    echo "0|0|$url|${err:-empty}"
    return 0
  fi
  local size final
  size=$(echo "$code" | cut -d'|' -f2)
  final=$(echo "$code" | cut -d'|' -f3)
  code=$(echo "$code" | cut -d'|' -f1)
  rm -f "$tmp"
  echo "${code}|${size}|${final}|${err}"
}
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f validate_status 2>/dev/null || true
fi
