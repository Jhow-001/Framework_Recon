#!/bin/bash
# content.sh — fingerprint do body
validate_content() {
  local url="$1"
  [[ -z "$url" || "$url" != http* ]] && { echo "empty|"; return 0; }
  local body
  body=$(curl -sS -L --max-redirs 3 \
    -A "Mozilla/5.0 (compatible; ReconFramework/2.0)" \
    --connect-timeout 5 --max-time 10 \
    "$url" 2>/dev/null | head -c 8192) || true
  if [[ -z "${body// }" ]]; then
    echo "empty|"
    return 0
  fi
  local snippet
  snippet=$(echo "$body" | tr '\n' ' ' | head -c 160)
  if echo "$body" | grep -qiE \
    'DB_PASSWORD|APP_KEY|AWS_SECRET|AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE KEY|jdbc:|mongodb(\+srv)?://|smtp\.|mail_password|api[_-]?key[[:space:]]*[:=]'; then
    echo "sensitive|${snippet}"
    return 0
  fi
  if echo "$body" | grep -qiE \
    '"status"[[:space:]]*:[[:space:]]*"UP"|phpinfo\(\)|Laravel|Ignition|Telescope|Traceback \(most recent'; then
    echo "sensitive|${snippet}"
    return 0
  fi
  if echo "$body" | grep -qiE \
    '<div id="__next"|__NEXT_DATA__|vercel|window\.__NUXT__|react\.root|ng-version'; then
    echo "spa|${snippet}"
    return 0
  fi
  if echo "$body" | grep -qiE '"status"|"healthy"|"ok"'; then
    echo "json_ok|${snippet}"
    return 0
  fi
  if echo "$body" | grep -qiE '404 Not Found|403 Forbidden|Attention Required|Access Denied'; then
    echo "error_page|${snippet}"
    return 0
  fi
  echo "generic|${snippet}"
}
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f validate_content 2>/dev/null || true
fi
