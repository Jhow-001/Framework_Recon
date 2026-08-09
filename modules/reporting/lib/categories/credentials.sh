#!/bin/bash
# credentials.sh — padrões de segredo; CRITICAL só com sinal forte
# Saída: hit|severity|cred_type|reason  ou  no|||

categorize_credentials() {
  local line="$1"
  local exp="${2:-no}"          # validate_exposure
  local exp_kind="${3:-}"
  local kind="${4:-}"           # content kind

  local sev="" ctype="" reason=""

  # private key / AWS
  if echo "$line" | grep -qiE 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|AKIA[0-9A-Z]{16}|aws_secret_access_key'; then
    echo "yes|CRITICAL|secret_key|credential_strong_pattern"
    return 0
  fi

  # connection strings / tokens longos
  if echo "$line" | grep -qiE 'mongodb(\+srv)?://[^[:space:]]+:[^[:space:]]+@|postgres://[^[:space:]]+:[^[:space:]]+@|mysql://[^[:space:]]+:[^[:space:]]+@'; then
    echo "yes|CRITICAL|connection_string|credential_conn_string"
    return 0
  fi

  # exposure validator já disse yes
  if [[ "$exp" == "yes" && "$exp_kind" == "secrets" ]]; then
    echo "yes|CRITICAL|secret|exposure_secrets"
    return 0
  fi

  # padrões fracos → não CRITICAL
  if echo "$line" | grep -qiE 'password\s*[:=]|passwd\s*[:=]|api[_-]?key\s*[:=]|secret\s*[:=]|token\s*[:=]'; then
    echo "yes|MEDIUM|password_like|credential_weak_pattern"
    return 0
  fi

  # emails em whois/osint → INFO
  if echo "$line" | grep -qiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'; then
    if echo "$line" | grep -qiE 'whois|registrant|admin|contato|contact'; then
      echo "yes|INFO|email|email_osint"
      return 0
    fi
  fi

  echo "no|||"
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f categorize_credentials 2>/dev/null || true
fi
