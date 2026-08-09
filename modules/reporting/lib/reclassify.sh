#!/bin/bash
# reclassify.sh — validate + categories (admin/credentials/access_control)

_VDIR="${ROOT_DIR}/modules/reporting/lib/validators"
_CDIR="${ROOT_DIR}/modules/reporting/lib/categories"

# shellcheck source=/dev/null
source "${_VDIR}/status.sh"
# shellcheck source=/dev/null
source "${_VDIR}/content.sh"
# shellcheck source=/dev/null
source "${_VDIR}/auth.sh"
# shellcheck source=/dev/null
source "${_VDIR}/tech.sh"
# shellcheck source=/dev/null
source "${_VDIR}/exposure.sh"
# shellcheck source=/dev/null
source "${_CDIR}/admin_panel.sh"
# shellcheck source=/dev/null
source "${_CDIR}/credentials.sh"
# shellcheck source=/dev/null
source "${_CDIR}/access_control.sh"

# prioridade de severidade para upgrade
_sev_rank() {
  case "$1" in
    CRITICAL) echo 5 ;;
    HIGH)     echo 4 ;;
    MEDIUM)   echo 3 ;;
    LOW)      echo 2 ;;
    INFO)     echo 1 ;;
    *)        echo 0 ;;
  esac
}

_upgrade_sev() {
  local cur="$1" new="$2"
  local rc rn
  rc=$(_sev_rank "$cur")
  rn=$(_sev_rank "$new")
  if [[ "$rn" -gt "$rc" ]]; then
    echo "$new"
  else
    echo "$cur"
  fi
}

reclassify_work() {
  set +e
  local work="$1"
  local max_validate="${VALIDATE_MAX:-40}"
  local conf_file="${work}/_validated.tsv"
  local cat_file="${work}/_categories.tsv"
  : > "$conf_file"
  : > "$cat_file"

  local tmp_all new_c new_h new_m new_l new_i
  tmp_all=$(mktemp)
  new_c=$(mktemp); new_h=$(mktemp); new_m=$(mktemp)
  new_l=$(mktemp); new_i=$(mktemp)

  cat "${work}/CRITICAL.txt" "${work}/HIGH.txt" 2>/dev/null \
    | sed '/^$/d' | sort -u > "${work}/_candidates_all.txt"

  head -n "$max_validate" "${work}/_candidates_all.txt" > "$tmp_all"
  tail -n +$((max_validate + 1)) "${work}/_candidates_all.txt" >> "$new_h" 2>/dev/null || true

  local total n line code size final err kind snippet url new_sev reason
  local auth tech tech_ver exp exp_kind st ct
  local hit sev ctype reason_c panel subtype

  total=$(wc -l < "$tmp_all" | tr -d ' ')
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Validando ${total} candidatos (max=${max_validate})"

  n=0
  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    [[ -z "${line// }" ]] && continue
    n=$((n + 1))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ($n/$total) ${line:0:80}"

    code="0"; size="0"; final=""; err=""; kind="empty"; snippet=""; url=""
    auth="unknown"; tech="unknown"; tech_ver=""; exp="no"; exp_kind=""

    st=$(validate_status "$line" 2>/dev/null) || st="0|0||curl_fail"
    IFS='|' read -r code size final err <<< "${st}|||"
    code="${code:-0}"; size="${size:-0}"; url="${final:-}"
    [[ -z "$url" ]] && url=$(echo "$line" | grep -oE 'https?://[^[:space:]]+' | head -1)

    if [[ -n "$url" && "$code" =~ ^(200|201|204|301|302|401|403)$ ]]; then
      ct=$(validate_content "$url" 2>/dev/null) || ct="empty|"
      IFS='|' read -r kind snippet <<< "${ct}|"
      kind="${kind:-empty}"
    fi

    if [[ -n "$url" && "$url" == http* && "$code" =~ ^(200|201|204|401|403|301|302)$ ]]; then
      auth=$(validate_auth "$url" 2>/dev/null || echo "unknown")
      IFS='|' read -r tech tech_ver < <(validate_tech "$url" 2>/dev/null || echo "unknown|")
      tech="${tech:-unknown}"
      IFS='|' read -r exp exp_kind < <(validate_exposure "$url" 2>/dev/null || echo "no|")
      exp="${exp:-no}"
    fi

    new_sev="HIGH"
    reason="validated_keep"

    if [[ "$exp" == "yes" ]]; then
      new_sev="CRITICAL"; reason="exposure_${exp_kind:-confirmed}"
    elif [[ "$kind" == "sensitive" ]]; then
      new_sev="CRITICAL"; reason="sensitive_content_http_${code}"
    elif [[ "$code" == "401" || "$code" == "403" || "$auth" == "auth_required" ]]; then
      new_sev="HIGH"; reason="auth_required_${code}"
    elif [[ "$kind" == "json_ok" ]]; then
      new_sev="HIGH"; reason="json_health_or_api_${code}"
    elif [[ "$tech" == "odoo" || "$tech" == "jenkins" || "$tech" == "grafana" || "$tech" == "phpmyadmin" ]]; then
      new_sev="HIGH"; reason="tech_panel_${tech}${tech_ver:+_v${tech_ver}}"
    elif [[ "$kind" == "spa" && "$code" == "200" ]]; then
      new_sev="LOW"; reason="spa_false_positive"
    elif [[ "$code" == "404" || "$kind" == "error_page" ]]; then
      if echo "$line" | grep -qiE 'development|sandbox|staging|odoo|:(8080|8443|3000|5000)'; then
        new_sev="HIGH"; reason="sensitive_host_even_if_${code}"
      else
        new_sev="INFO"; reason="not_found_or_error"
      fi
    elif [[ "$code" == "0" || "$code" == "000" ]]; then
      if echo "$line" | grep -qiE 'development|sandbox|odoo|:(8080|8443)'; then
        new_sev="HIGH"; reason="host_signal_curl_fail"
      else
        new_sev="INFO"; reason="curl_fail"
      fi
    elif [[ "$kind" == "empty" && "$code" == "200" ]]; then
      new_sev="MEDIUM"; reason="empty_200"
    elif [[ "$kind" == "generic" && "$code" == "200" ]]; then
      if echo "$line" | grep -qiE 'actuator|\.env|phpinfo|/debug|development\.log'; then
        if echo "$line" | grep -qiE 'development|sandbox|odoo|api\.'; then
          new_sev="HIGH"; reason="generic_on_sensitive_host"
        else
          new_sev="LOW"; reason="generic_html_unconfirmed"
        fi
      fi
    fi

    # ----- Fase 4: categorias (podem subir severidade) -----
    IFS='|' read -r hit sev ctype reason_c < <(categorize_credentials "$line" "$exp" "$exp_kind" "$kind")
    if [[ "$hit" == "yes" ]]; then
      new_sev=$(_upgrade_sev "$new_sev" "$sev")
      reason="${reason_c}"
      printf '%s\t%s\t%s\t%s\t%s\n' "credentials" "$sev" "$ctype" "$reason_c" "$line" >> "$cat_file"
    fi

    IFS='|' read -r hit sev panel reason_c < <(categorize_admin_panel "$line" "$tech" "$auth" "$code")
    if [[ "$hit" == "yes" ]]; then
      new_sev=$(_upgrade_sev "$new_sev" "$sev")
      reason="${reason_c}"
      printf '%s\t%s\t%s\t%s\t%s\n' "admin_panel" "$sev" "$panel" "$reason_c" "$line" >> "$cat_file"
    fi

    IFS='|' read -r hit sev subtype reason_c < <(categorize_access_control "$line" "")
    if [[ "$hit" == "yes" ]]; then
      new_sev=$(_upgrade_sev "$new_sev" "$sev")
      reason="${reason_c}"
      printf '%s\t%s\t%s\t%s\t%s\n' "access_control" "$sev" "$subtype" "$reason_c" "$line" >> "$cat_file"
    fi

    case "$new_sev" in
      CRITICAL) printf '%s\n' "$line" >> "$new_c" ;;
      HIGH)     printf '%s\n' "$line" >> "$new_h" ;;
      MEDIUM)   printf '%s\n' "$line" >> "$new_m" ;;
      LOW)      printf '%s\n' "$line" >> "$new_l" ;;
      *)        printf '%s\n' "$line" >> "$new_i" ;;
    esac

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$new_sev" "$code" "$size" "$kind" "$reason" "${url:-}" \
      "$auth" "$tech" "$exp" "$line" >> "$conf_file"
  done < "$tmp_all"

  sort -u "$new_c" -o "${work}/CRITICAL.txt" 2>/dev/null || : > "${work}/CRITICAL.txt"
  sort -u "$new_h" -o "${work}/HIGH.txt" 2>/dev/null || : > "${work}/HIGH.txt"
  if [[ -s "$new_m" ]]; then cat "$new_m" >> "${work}/MEDIUM.txt"; sort -u -o "${work}/MEDIUM.txt" "${work}/MEDIUM.txt"; fi
  if [[ -s "$new_l" ]]; then cat "$new_l" >> "${work}/LOW.txt"; sort -u -o "${work}/LOW.txt" "${work}/LOW.txt"; fi
  if [[ -s "$new_i" ]]; then cat "$new_i" >> "${work}/INFO.txt"; sort -u -o "${work}/INFO.txt" "${work}/INFO.txt"; fi

  rm -f "$tmp_all" "$new_c" "$new_h" "$new_m" "$new_l" "$new_i"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Pós-validate: C=$(wc -l < "${work}/CRITICAL.txt" | tr -d ' ') H=$(wc -l < "${work}/HIGH.txt" | tr -d ' ') L=$(wc -l < "${work}/LOW.txt" | tr -d ' ')"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Categories: $(wc -l < "$cat_file" | tr -d ' ') hits → ${cat_file}"
  set -e
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f reclassify_work 2>/dev/null || true
fi
