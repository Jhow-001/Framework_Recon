#!/bin/bash
# run.sh - Ponto de entrada V2 (pipeline completo)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/core/bootstrap/bootstrap.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/core/runtime/module_runner.sh"

if [[ $# -lt 1 ]]; then
    echo "Uso: $0 <domínio> [módulo_único]"
    echo "  $0 example.com              # pipeline completo"
    echo "  $0 example.com subdomains   # só um módulo (debug)"
    exit 1
fi

DOMAIN="$1"
SINGLE_MODULE="${2:-}"

export TARGET_DOMAIN="$DOMAIN"
export DOMAIN
export RESULTS_BASE="${ROOT_DIR}/results/${DOMAIN}"
export PIPELINE_CONF="${ROOT_DIR}/config/pipeline.conf"

# Perfis de execução
case "${PROFILE:-standard}" in
  fast)
    export RETRY_MAX=0 TIMEOUT_TOOL=300 MAX_PARALLEL=4
    export CRAWL_MAX_JS=100 CRAWL_MAX_API=80 CRAWL_MAX_PARAMS=100
    export CRAWL_MAX_JWT=50 CRAWL_MAX_VULN=80 FUZZ_MAX_URLS=10
    log_info "Perfil: FAST"
    ;;
  deep)
    export RETRY_MAX=1 TIMEOUT_TOOL=1800 MAX_PARALLEL=8
    export CRAWL_MAX_JS=2000 CRAWL_MAX_API=1500 CRAWL_MAX_PARAMS=2000
    export CRAWL_MAX_JWT=500 CRAWL_MAX_VULN=1500 FUZZ_MAX_URLS=50
    log_info "Perfil: DEEP"
    ;;
  *)
    log_info "Perfil: STANDARD"
    ;;
esac

# ---------------------------------------------------------------------------
# Dashboard (local only — 127.0.0.1)
# ---------------------------------------------------------------------------
start_dashboard() {
    local web_dir="${ROOT_DIR}/dashboard/web"
    local port=8080
    local log_file="${ROOT_DIR}/logs/dashboard.log"
    local pid_file="${ROOT_DIR}/logs/dashboard.pid"

    mkdir -p "${ROOT_DIR}/logs"

    if ! [[ -f "${web_dir}/app.py" ]]; then
        log_warn "Dashboard not found at dashboard/web/app.py — skip"
        return 0
    fi

    if ss -ltn 2>/dev/null | grep -q ":${port} " || \
       netstat -ltn 2>/dev/null | grep -q ":${port} "; then
        log_info "Dashboard already on :${port}"
    else
        log_info "Starting dashboard http://127.0.0.1:${port}/"
        (
            cd "${web_dir}" || exit 0
            if [[ -f .venv/bin/activate ]]; then
                # shellcheck disable=SC1091
                source .venv/bin/activate
            fi
            nohup python3 app.py >>"${log_file}" 2>&1 &
            echo $! >"${pid_file}"
        )
        sleep 1
    fi

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "http://127.0.0.1:${port}/" >/dev/null 2>&1 || true
    elif command -v sensible-browser >/dev/null 2>&1; then
        sensible-browser "http://127.0.0.1:${port}/" >/dev/null 2>&1 || true
    else
        log_info "Open dashboard: http://127.0.0.1:${port}/"
    fi
}

print_banner
log_info "Iniciando Framework Recon V2 para: ${DOMAIN}"
start_dashboard

storage_ensure_base "$DOMAIN"
events_init "$DOMAIN"

TOTAL_MODULES=0
if [[ -f "$PIPELINE_CONF" ]]; then
    TOTAL_MODULES=$(grep -E '^\s*[0-9]+\s*\|' "$PIPELINE_CONF" | grep -v '^\s*#' | wc -l | tr -d ' ')
fi

metrics_init "$DOMAIN"
metrics_run_start "$DOMAIN" "${TOTAL_MODULES:-0}"

events_emit "RUN_START" "target=${DOMAIN}"
storage_update_run --argjson total "${TOTAL_MODULES:-1}" '.modules_total = $total | .status = "running"'

if [[ -n "$SINGLE_MODULE" ]]; then
    log_info "Modo módulo único: ${SINGLE_MODULE}"
    INPUT_DIR=$(storage_tmp)
    INPUT_FILE="${INPUT_DIR}/${DOMAIN}_input.txt"
    echo "$DOMAIN" > "$INPUT_FILE"
    module_run "$SINGLE_MODULE" "$INPUT_FILE"
else
    log_info "Modo pipeline completo | conf=${PIPELINE_CONF}"
    bash "${ROOT_DIR}/core/scheduler/scheduler.sh"
fi

# Reporting (fora do grafo de módulos)
# Reporting V2 (gold + superfície)
if [[ -f "${ROOT_DIR}/modules/reporting/reporting.sh" ]]; then
    log_info "Gerando relatório prioritizado para: ${DOMAIN}"
    bash "${ROOT_DIR}/modules/reporting/reporting.sh" "$DOMAIN" \
        || log_warn "Reporting V2 retornou erro (run não aborta)"
else
    log_warn "modules/reporting/reporting.sh ausente — skip report"
fi

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
storage_update_run --arg f "$now" '.status = "finished" | .finished = $f'
events_emit "RUN_END" "target=${DOMAIN}"
metrics_run_end "finished"

# Limpeza de cache e logs após término do pipeline
storage_cleanup_runtime
log_info "Limpeza de cache/logs concluída"

log_ok "=============================================="
log_ok " Framework V2 finalizado - ${DOMAIN}"
log_ok " Resultados em: results/${DOMAIN}/"
log_ok "=============================================="
