#!/bin/bash
# classify.sh — classificação CONSERVADORA (HIGH limpo)

RE_ENV_HIGH='(^|[./])(api\.)?(development|sandbox|staging|dev|homolog|qa)\.|odoo\.|jenkins\.|grafana\.|kibana\.|gitlab\.'
RE_PORT_HIGH=':(8080|8443|3000|5000|8000|9000|9090)(/|$|\s)'
RE_HEALTH='/(healthz?|health/ready|health/live)(/|$|\?|\s)'
RE_EXPOSURE_PATH='\.(env|git/config)|actuator|/debug|_ignition|telescope|horizon|phpinfo|server-status|server-info|wp-config|\.aws/credentials'
RE_CREDS='(AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|aws_secret_access_key|api[_-]?key[[:space:]]*[:=]|password[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,})'
RE_CONFIRMED_VULN='\[critical\]|\[high\]|injectable|Parameter:|POC|reflected|confirmed'
RE_NOISE='wp-json|gtag/js|googletagmanager|favicon\.ico|_next/static|\.js(\?|$)|sitemap\.xml|\.css(\?|$)'
RE_SCANNER_NOISE='ssl-cert:|Subject Alternative|Nmap scan report|None \(None\)|alert\(|UNION\+SELECT|information_schema|\.\./\.\./etc/passwd|Did not follow redirect'

classify_line() {
  local line="$1"
  local source="${2:-unknown}"
  [[ -z "${line// }" ]] && { echo "INFO|low|empty"; return; }

  if echo "$line" | grep -qiE "$RE_NOISE"; then
    echo "INFO|low|noise_spa_or_static"
    return
  fi

  if echo "$line" | grep -qiE "$RE_SCANNER_NOISE"; then
    echo "INFO|low|scanner_noise"
    return
  fi

  # Painel só path → LOW (sobe na Fase 2 se validado)
  if echo "$line" | grep -qiE 'phpmyadmin|adminer|dh_phpmyadmin'; then
    echo "LOW|low|admin_panel_path_only"
    return
  fi

  # CRITICAL / HIGH por tool de confirmação
  if echo "$source" | grep -qiE 'nuclei_vul|nuclei_exposure|sqlmap|dalfox'; then
    if echo "$line" | grep -qiE "$RE_CONFIRMED_VULN|$RE_EXPOSURE_PATH|$RE_CREDS"; then
      if echo "$line" | grep -qiE '\[critical\]|\[high\]|injectable|POC|PRIVATE KEY|AKIA'; then
        echo "CRITICAL|high|confirmed_by_${source}"
        return
      fi
      echo "HIGH|medium|tool_signal_${source}"
      return
    fi
  fi

  if echo "$line" | grep -qiE "$RE_CREDS"; then
    echo "CRITICAL|medium|credential_pattern"
    return
  fi

  if echo "$line" | grep -qiE 'bucket|s3\.|\.s3\.|storage\.googleapis'; then
    if echo "$line" | grep -qiE 'listable|public|AccessDenied|GetObject|ListBucket'; then
      echo "CRITICAL|high|bucket_access_signal"
      return
    fi
    echo "INFO|low|bucket_name_only"
    return
  fi

  # HIGH real
  if echo "$line" | grep -qiE "$RE_ENV_HIGH"; then
    echo "HIGH|medium|sensitive_environment_or_panel"
    return
  fi

  if echo "$line" | grep -qiE "$RE_PORT_HIGH"; then
    echo "HIGH|medium|non_standard_port"
    return
  fi

  if echo "$line" | grep -qiE "$RE_HEALTH"; then
    echo "HIGH|low|api_health_endpoint"
    return
  fi

  # exposure path sem confirmação (ffuf/SPA)
  if echo "$source" | grep -qiE 'ffuf|fuzzing|exposure'; then
    if echo "$line" | grep -qiE "$RE_EXPOSURE_PATH"; then
      echo "LOW|low|exposure_path_unconfirmed_spa"
      return
    fi
  fi

  # actuator/health em host “marketing” (sem api/dev) → LOW
  if echo "$line" | grep -qiE "$RE_EXPOSURE_PATH"; then
    if ! echo "$line" | grep -qiE 'api\.|development|sandbox|staging'; then
      echo "LOW|low|exposure_path_unconfirmed"
      return
    fi
  fi

  if echo "$source" | grep -qiE 'vulnerability|access_control'; then
    if echo "$line" | grep -qiE 'idor|bola|bfla|unauthorized|access.control'; then
      echo "MEDIUM|low|access_control_candidate"
      return
    fi
  fi

  if echo "$source" | grep -qiE 'ports_scan|nmap|naabu|waf'; then
    echo "MEDIUM|medium|infra_signal"
    return
  fi

  if echo "$source" | grep -qiE 'http_probe|httpx|subdomains|dns'; then
    echo "MEDIUM|low|asset_discovery"
    return
  fi

  echo "INFO|low|unclassified"
}

classify_file() {
  local infile="$1"
  local source="$2"
  local outdir="$3"
  [[ -f "$infile" && -s "$infile" ]] || return 0
  mkdir -p "$outdir"

  local line sev conf reason
  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    [[ -z "${line// }" ]] && continue
    [[ ${#line} -gt 2000 ]] && line="${line:0:2000}"
    IFS='|' read -r sev conf reason < <(classify_line "$line" "$source")
    case "$sev" in
      CRITICAL|HIGH|MEDIUM|LOW|INFO) ;;
      *) sev="INFO" ;;
    esac
    printf '%s\n' "$line" >> "${outdir}/${sev}.txt"
    printf '%s\t%s\t%s\t%s\t%s\n' "$sev" "$conf" "$source" "$reason" "$line" >> "${outdir}/_index.tsv"
  done < "$infile"
}

export -f classify_line classify_file
