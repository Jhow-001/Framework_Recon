#!/bin/bash
# core/scheduler/scheduler.sh
# Scheduler V2 — dependências por artefato, PIDs, skip starved, screenshots env

set -euo pipefail

SCHED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "${SCHED_DIR}/../.." && pwd)}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/core/bootstrap/bootstrap.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/core/runtime/module_runner.sh"
# shellcheck source=/dev/null
source "${SCHED_DIR}/resolve_input.sh"

DOMAIN="${TARGET_DOMAIN:-${DOMAIN:-}}"
RESULTS_BASE="${RESULTS_BASE:-${ROOT_DIR}/results/${DOMAIN}}"
PIPELINE_CONF="${PIPELINE_CONF:-${ROOT_DIR}/config/pipeline.conf}"
POLL_SEC="${SCHEDULER_POLL_SEC:-2}"

[[ -n "$DOMAIN" && -n "$ROOT_DIR" ]] || {
    echo "[scheduler] DOMAIN/ROOT_DIR não definidos" >&2
    exit 1
}
[[ -f "$PIPELINE_CONF" ]] || {
    echo "[scheduler] pipeline.conf não encontrado: $PIPELINE_CONF" >&2
    exit 1
}

mkdir -p "$RESULTS_BASE"
storage_ensure_base "$DOMAIN"
events_init "$DOMAIN"

export -f log_info log_warn log_error log_ok 2>/dev/null || true
export -f module_run tool_run 2>/dev/null || true
export -f storage_ensure_base storage_ensure_module storage_update_module storage_update_run 2>/dev/null || true
export -f storage_module_dir storage_module_txt storage_module_json 2>/dev/null || true
export -f events_init events_emit 2>/dev/null || true
export -f resolve_input 2>/dev/null || true

declare -a MOD_NAMES=()
declare -A MOD_SCRIPT MOD_INPUT MOD_OUTPUT MOD_STATE MOD_PID

while IFS='|' read -r phase name script input output || [[ -n "${phase:-}" ]]; do
    [[ -z "${phase// }" || "$phase" =~ ^[[:space:]]*# ]] && continue
    name=$(echo "$name" | xargs)
    script=$(echo "$script" | xargs)
    input=$(echo "$input" | xargs)
    output=$(echo "$output" | xargs)
    [[ -z "$name" ]] && continue
    MOD_NAMES+=("$name")
    MOD_SCRIPT["$name"]="${ROOT_DIR}/${script}"
    MOD_INPUT["$name"]="$input"
    MOD_OUTPUT["$name"]="$output"
done < "$PIPELINE_CONF"

TOTAL=${#MOD_NAMES[@]}
log_info "Scheduler: ${TOTAL} módulos | poll=${POLL_SEC}s | target=${DOMAIN}"
events_emit "SCHEDULER_START" "target=${DOMAIN}" "modules=${TOTAL}"

for name in "${MOD_NAMES[@]}"; do
    MOD_STATE["$name"]="waiting"
done

_resume_from_state() {
    local status_dir modules_json name st
    status_dir=$(storage_status_dir "$DOMAIN")
    modules_json="${status_dir}/modules.json"
    [[ -f "$modules_json" ]] || return 0
    for name in "${MOD_NAMES[@]}"; do
        st=$(jq -r --arg m "$name" '.[$m].status // empty' "$modules_json" 2>/dev/null || true)
        if [[ "$st" == "ok" ]]; then
            MOD_STATE["$name"]="completed"
            log_info "Retomada: ${name} já concluído — skipped"
        fi
    done
}
_resume_from_state

all_non_reporting_done() {
    local n
    for n in "${MOD_NAMES[@]}"; do
        [[ "$n" == "reporting" ]] && continue
        [[ "${MOD_STATE[$n]}" == "completed" || "${MOD_STATE[$n]}" == "skipped" || "${MOD_STATE[$n]}" == "failed" ]] || return 1
    done
    return 0
}

count_done() {
    local c=0 n
    for n in "${MOD_NAMES[@]}"; do
        [[ "${MOD_STATE[$n]}" == "completed" || "${MOD_STATE[$n]}" == "skipped" || "${MOD_STATE[$n]}" == "failed" ]] && ((c++)) || true
    done
    echo "$c"
}

can_start() {
    local name="$1"
    local ref="${MOD_INPUT[$name]}"
    local resolved

    [[ "${MOD_STATE[$name]}" == "waiting" ]] || return 1

    if [[ "$ref" == "ALL" ]]; then
        all_non_reporting_done || return 1
        return 0
    fi
    if [[ "$ref" == "DOMAIN" ]]; then
        return 0
    fi

    resolved=$(resolve_input "$ref" "$DOMAIN" "$RESULTS_BASE")
    [[ -n "$resolved" ]] || return 1
    return 0
}

# Artefatos canônicos + os gerados no module_finalize (ex.: crawling → js.txt)
declare -A ARTIFACT_PRODUCER=(
  [subdomains.txt]=subdomains
  [osint.txt]=osint
  [cloud.txt]=cloud
  [dns.txt]=dns_resolution
  [http.txt]=http_probe
  [ports.txt]=ports_scan
  [waf.txt]=waf_detection
  [screenshots.txt]=screenshots
  [exposure.txt]=exposure_assessment
  [crawling.txt]=crawling
  [fuzzing.txt]=fuzzing
  [js.txt]=crawling
  [api_endpoints.txt]=crawling
  [parameters.txt]=crawling
  [jwt_candidates.txt]=crawling
  [forms.txt]=crawling
  [urls.txt]=crawling
  [vuln_targets.txt]=crawling
  [validated_secrets.txt]=osint_validation
  [javascript.txt]=javascript
  [api.txt]=api
  [access_control.txt]=access_control
  [jwt_analysis.txt]=jwt_analysis
  [vulnerability.txt]=vulnerability
)

_producers_pending() {
    local ref="$1" n prod
    prod="${ARTIFACT_PRODUCER[$ref]:-}"
    if [[ -n "$prod" ]]; then
        # Módulo produtor ainda pode rodar / gerar o artefato
        if [[ -z "${MOD_STATE[$prod]:-}" ]]; then
            return 0
        fi
        case "${MOD_STATE[$prod]}" in
            waiting|running|queued) return 0 ;;
            *) ;; # completed|failed|skipped → cai no fallback
        esac
        # Produtor conhecido já terminou: não há mais quem gere este ref
        return 1
    fi
    # fallback: coluna SAÍDA do pipeline.conf
    for n in "${MOD_NAMES[@]}"; do
        [[ "${MOD_OUTPUT[$n]}" == "$ref" ]] || continue
        case "${MOD_STATE[$n]}" in
            waiting|running|queued) return 0 ;;
        esac
    done
    return 1
}

maybe_skip_starved() {
    local name ref resolved
    for name in "${MOD_NAMES[@]}"; do
        [[ "${MOD_STATE[$name]}" == "waiting" ]] || continue
        ref="${MOD_INPUT[$name]}"
        [[ "$ref" == "DOMAIN" || "$ref" == "ALL" ]] && continue

        resolved=$(resolve_input "$ref" "$DOMAIN" "$RESULTS_BASE")
        [[ -n "$resolved" ]] && continue

        if ! _producers_pending "$ref"; then
            MOD_STATE["$name"]="skipped"
            log_warn "Skip ${name}: input ${ref} indisponível (produtores finalizados)"
            events_emit "MODULE_SKIPPED" "module=${name}" "reason=missing_input" 2>/dev/null || true
        fi
    done
}

count_running() {
    local c=0 n
    for n in "${MOD_NAMES[@]}"; do
        [[ "${MOD_STATE[$n]}" == "running" ]] && ((c++)) || true
    done
    echo "$c"
}

max_module_workers() {
    local max="${MAX_PARALLEL:-0}"
    local cores
    if [[ "$max" -eq 0 ]]; then
        cores=$(nproc 2>/dev/null || echo 4)
        max=$((cores * 2))
    fi
    if [[ "$max" -gt 8 ]]; then
        max=8
    fi
    echo "$max"
}

memory_free_percent() {
    local mem_total mem_available
    if [[ -r /proc/meminfo ]]; then
        mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        mem_available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        if [[ -n "$mem_total" && "$mem_total" -gt 0 ]]; then
            echo $(( mem_available * 100 / mem_total ))
            return 0
        fi
    fi
    echo 100
}

memory_allows_start() {
    local min_free="${MEMORY_MIN_FREE_PERCENT:-15}"
    local free
    free=$(memory_free_percent)
    if (( free < min_free )); then
        return 1
    fi
    return 0
}

start_module() {
    local name="$1"
    local script="${MOD_SCRIPT[$name]}"
    local ref="${MOD_INPUT[$name]}"
    local resolved pid input_for_module

    if [[ ! -f "$script" ]]; then
        log_warn "Script não encontrado: $script ($name) — skipped"
        MOD_STATE["$name"]="skipped"
        return 0
    fi

    resolved=$(resolve_input "$ref" "$DOMAIN" "$RESULTS_BASE")
    log_info "→ Iniciando módulo: $name (input=${ref})"
    events_emit "MODULE_QUEUED" "module=${name}"

    if [[ "$ref" == "DOMAIN" ]]; then
        input_for_module="${RESULTS_BASE}/.domain_input.txt"
        echo "$DOMAIN" > "$input_for_module"
    elif [[ "$ref" == "ALL" ]]; then
        input_for_module="$RESULTS_BASE"
    else
        if [[ -z "$resolved" || ! -s "$resolved" ]]; then
            log_warn "Entrada ainda inválida para $name — adia"
            return 0
        fi
        input_for_module="$resolved"
    fi

    (
        export TARGET_DOMAIN="$DOMAIN"
        export DOMAIN
        export ROOT_DIR
        if [[ "$name" == "screenshots" ]]; then
            export SCREENSHOTS_DIR="${RESULTS_BASE}/screenshots/images"
            mkdir -p "$SCREENSHOTS_DIR"
        fi
        storage_ensure_base "$DOMAIN"
        events_init "$DOMAIN"

        set +e
        if grep -q "module_tools" "$script" 2>/dev/null; then
            module_run "$name" "$input_for_module"
            ec=$?
        else
            log_warn "Módulo ${name} ainda no formato legado — executando script direto"
            if [[ "$ref" == "DOMAIN" ]]; then
                bash "$script" "$DOMAIN"
            elif [[ "$ref" == "ALL" ]]; then
                bash "$script" "$RESULTS_BASE"
            else
                bash "$script" "$input_for_module"
            fi
            ec=$?
        fi
        set -e
        exit "$ec"
    ) &

    pid=$!
    MOD_PID["$name"]=$pid
    MOD_STATE["$name"]="running"
    events_emit "MODULE_RUNNING" "module=${name}" "pid=${pid}"
}

reap_finished() {
    local name pid ec
    for name in "${MOD_NAMES[@]}"; do
        [[ "${MOD_STATE[$name]}" == "running" ]] || continue
        pid="${MOD_PID[$name]:-}"
        [[ -n "$pid" ]] || continue
        if ! kill -0 "$pid" 2>/dev/null; then
            set +e
            wait "$pid"
            ec=$?
            set -e
            if [[ $ec -eq 0 ]]; then
                MOD_STATE["$name"]="completed"
                log_ok "✓ Módulo finalizado: $name"
                events_emit "MODULE_COMPLETED" "module=${name}"
            else
                MOD_STATE["$name"]="failed"
                log_warn "✗ Módulo falhou: $name (exit=${ec})"
                events_emit "MODULE_FAILED" "module=${name}" "exit=${ec}"
            fi
            unset "MOD_PID[$name]"
        fi
    done
}

all_done() {
    local n
    for n in "${MOD_NAMES[@]}"; do
        [[ "${MOD_STATE[$n]}" == "completed" || "${MOD_STATE[$n]}" == "skipped" || "${MOD_STATE[$n]}" == "failed" ]] || return 1
    done
    return 0
}

_scheduler_cancelled=0

_scheduler_cleanup() {
    # Limpeza de runtime sempre (sucesso ou cancelamento)
    if declare -f storage_cleanup_runtime >/dev/null 2>&1; then
        storage_cleanup_runtime
    fi

    [[ "${_scheduler_cancelled}" -eq 1 ]] || return 0
    log_warn "Scheduler: cancelamento solicitado"
    events_emit "RUN_CANCELLED" "target=${DOMAIN}" 2>/dev/null || true
    local name pid
    for name in "${MOD_NAMES[@]}"; do
        pid="${MOD_PID[$name]:-}"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    sleep 2
    for name in "${MOD_NAMES[@]}"; do
        pid="${MOD_PID[$name]:-}"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
}

_on_signal() {
    _scheduler_cancelled=1
    exit 130
}

trap _on_signal INT TERM
trap _scheduler_cleanup EXIT

max_workers=$(max_module_workers)
log_info "Scheduler: max módulos em paralelo = ${max_workers}"

while true; do
    reap_finished
    maybe_skip_starved

    running=$(count_running)
    for name in "${MOD_NAMES[@]}"; do
        if (( running >= max_workers )); then
            break
        fi
        if ! memory_allows_start; then
            log_warn "Memória livre abaixo do limite (${MEMORY_MIN_FREE_PERCENT:-15}%) — adia novos módulos"
            break
        fi
        if can_start "$name"; then
            start_module "$name"
            running=$(count_running)
        fi
    done

    if all_done; then
        log_ok "Scheduler: todos os módulos concluídos ($(count_done)/${TOTAL})"
        break
    fi
    sleep "$POLL_SEC"
done

trap - EXIT INT TERM
events_emit "SCHEDULER_END" "target=${DOMAIN}" "done=$(count_done)"
