#!/bin/bash
# access_control.sh — IDOR/BOLA/BFLA candidates (não confirma explotação)
# Saída: hit|severity|subtype|reason  ou  no|||

categorize_access_control() {
  local line="$1"
  local source="${2:-}"

  # só interessa se veio de módulos de access/vuln/api
  if ! echo "$source $line" | grep -qiE 'access_control|bola|idor|bfla|unauthorized|forbidden|nuclei_access|api/'; then
    # ainda assim paths típicos
    if ! echo "$line" | grep -qiE '/(user|users|account|accounts|order|orders|admin|role|roles)/[0-9]+|/api/v[0-9]+/[^[:space:]]*[0-9]{2,}'; then
      echo "no|||"
      return 0
    fi
  fi

  local subtype="unauthorized_resource_access"
  echo "$line" | grep -qiE 'idor' && subtype="IDOR"
  echo "$line" | grep -qiE 'bola' && subtype="BOLA"
  echo "$line" | grep -qiE 'bfla' && subtype="BFLA"
  echo "$line" | grep -qiE 'horizontal' && subtype="horizontal_privilege_escalation"
  echo "$line" | grep -qiE 'vertical' && subtype="vertical_privilege_escalation"

  # candidato — MEDIUM até validação manual/autorizada
  local sev="MEDIUM"
  local reason="access_control_candidate_${subtype}"

  # nuclei com severity high/critical no texto
  if echo "$line" | grep -qiE '\[critical\]|\[high\]'; then
    sev="HIGH"
    reason="access_control_nuclei_${subtype}"
  fi

  echo "yes|${sev}|${subtype}|${reason}"
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f categorize_access_control 2>/dev/null || true
fi
