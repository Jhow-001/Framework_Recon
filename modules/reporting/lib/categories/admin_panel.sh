#!/bin/bash
# admin_panel.sh — detecta painéis; severidade só sobe com tech/auth/versão
# Saída: hit|severity|panel_type|reason   ou   no|||

RE_PANEL='phpmyadmin|adminer|wp-admin|wp-login|jenkins|grafana|kibana|gitlab|odoo|portainer|sonarqube|rabbitmq|swagger|api-docs|actuator|telescope|horizon|_ignition|phpinfo|server-status|server-info'

categorize_admin_panel() {
  local line="$1"
  local tech="${2:-unknown}"
  local auth="${3:-unknown}"
  local code="${4:-0}"

  if ! echo "$line" | grep -qiE "$RE_PANEL"; then
    echo "no|||"
    return 0
  fi

  local panel="generic"
  echo "$line" | grep -qiE 'phpmyadmin' && panel="phpmyadmin"
  echo "$line" | grep -qiE 'adminer' && panel="adminer"
  echo "$line" | grep -qiE 'jenkins' && panel="jenkins"
  echo "$line" | grep -qiE 'grafana' && panel="grafana"
  echo "$line" | grep -qiE 'kibana' && panel="kibana"
  echo "$line" | grep -qiE 'gitlab' && panel="gitlab"
  echo "$line" | grep -qiE 'odoo' && panel="odoo"
  echo "$line" | grep -qiE 'actuator' && panel="actuator"
  echo "$line" | grep -qiE 'telescope|horizon|_ignition|phpinfo' && panel="debug"

  # path sozinho → LOW/INFO
  local sev="LOW"
  local reason="admin_panel_path_only"

  # tech confirmada pelo validator
  if [[ "$tech" == "odoo" || "$tech" == "jenkins" || "$tech" == "grafana" || "$tech" == "phpmyadmin" ]]; then
    sev="HIGH"
    reason="admin_panel_tech_${tech}"
  fi

  # aberto (200) em painel conhecido → HIGH
  if [[ "$code" == "200" && "$auth" == "open" && "$panel" != "generic" ]]; then
    sev="HIGH"
    reason="admin_panel_open_${panel}"
  fi

  # exige auth → MEDIUM (superfície real, não dump)
  if [[ "$auth" == "auth_required" ]]; then
    sev="MEDIUM"
    reason="admin_panel_auth_${panel}"
  fi

  # debug/actuator com exposure já tratado no reclassify (CRITICAL via exposure)
  if [[ "$panel" == "debug" || "$panel" == "actuator" ]]; then
    if [[ "$code" == "200" && "$auth" == "open" ]]; then
      sev="HIGH"
      reason="admin_panel_open"
    else
      sev="LOW"
      reason="admin_panel_unconfirmed"
    fi
  fi

  echo "yes|${sev}|${panel}|${reason}"
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f categorize_admin_panel 2>/dev/null || true
fi
