#!/bin/bash
# exposure.sh — saída: yes|no  +  kind opcional
validate_exposure() {
  local url="$1"
  [[ -z "$url" || "$url" != http* ]] && { echo "no|"; return 0; }
  local body
  body=$(curl -sS -L --max-redirs 2 \
    -A "Mozilla/5.0 (compatible; ReconFramework/2.0)" \
    --connect-timeout 5 --max-time 8 "$url" 2>/dev/null | head -c 12288) || true
  [[ -z "${body// }" ]] && { echo "no|"; return 0; }

  if echo "$body" | grep -qiE \
    'DB_PASSWORD|APP_KEY=|AWS_SECRET|AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE KEY|mail_password|SECRET_KEY\s*='; then
    echo "yes|secrets"
    return 0
  fi
  if echo "$body" | grep -qiE 'phpinfo\(\)|Laravel|Ignition|Telescope|Traceback \(most recent call last\)'; then
    echo "yes|debug"
    return 0
  fi
  if echo "$body" | grep -qiE '"status"\s*:\s*"UP".*("diskSpace"|"db")|application/vnd\.spring'; then
    echo "yes|actuator"
    return 0
  fi
  echo "no|"
}
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f validate_exposure 2>/dev/null || true
fi
