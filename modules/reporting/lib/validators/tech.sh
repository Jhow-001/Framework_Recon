#!/bin/bash
# tech.sh — saída: tech|version_guess (version pode ser vazio)
validate_tech() {
  local url="$1"
  [[ -z "$url" || "$url" != http* ]] && { echo "unknown|"; return 0; }
  local hdr body
  hdr=$(curl -sS -I -L --max-redirs 2 \
    -A "Mozilla/5.0 (compatible; ReconFramework/2.0)" \
    --connect-timeout 5 --max-time 8 "$url" 2>/dev/null | head -c 2048) || true
  body=$(curl -sS -L --max-redirs 2 \
    -A "Mozilla/5.0 (compatible; ReconFramework/2.0)" \
    --connect-timeout 5 --max-time 8 "$url" 2>/dev/null | head -c 4096) || true

  local tech="unknown" ver=""
  if echo "$hdr$body" | grep -qiE 'odoo|Odoo'; then
    tech="odoo"
    ver=$(echo "$body" | grep -oiE 'Odoo[ /]?[0-9.]+' | head -1 | grep -oE '[0-9.]+')
  elif echo "$hdr$body" | grep -qiE 'phpmyadmin'; then
    tech="phpmyadmin"
    ver=$(echo "$body" | grep -oiE 'phpMyAdmin [0-9.]+' | head -1 | grep -oE '[0-9.]+')
  elif echo "$hdr$body" | grep -qiE 'Jenkins'; then
    tech="jenkins"
  elif echo "$hdr$body" | grep -qiE 'Grafana'; then
    tech="grafana"
  elif echo "$hdr$body" | grep -qiE 'nginx'; then
    tech="nginx"
    ver=$(echo "$hdr" | grep -oiE 'nginx/[0-9.]+' | head -1 | cut -d/ -f2)
  elif echo "$body" | grep -qiE '__NEXT_DATA__|vercel'; then
    tech="next_vercel"
  elif echo "$body" | grep -qiE '"status"\s*:\s*"UP"'; then
    tech="spring_actuator"
  fi
  echo "${tech}|${ver}"
}
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f validate_tech 2>/dev/null || true
fi
