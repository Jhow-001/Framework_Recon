#!/bin/bash
# core/runtime/tool_runner.sh - V2 ToolRunner
set -euo pipefail

is_transient_error() {
    local code="$1"
    local _msg="${2:-}"
    case "$code" in
        1|2|255) return 0 ;;
        *) return 1 ;;
    esac
}

tool_run() {
    local module="$1"
    local tool="$2"
    local input_file="$3"
    local timeout_override="${4:-}"
    local tool_script="${MODULES_DIR}/${module}/tools/${tool}.sh"

    if [[ ! -f "$tool_script" ]]; then
        log_warn "Tool não encontrada: ${module}/${tool}"
        events_emit "TOOL_MISSING" "module=${module}" "tool=${tool}"
        storage_update_tool "${module}.${tool}" \
            --arg m "$module" --arg t "$tool" --arg st "missing" \
            '.[$k] = {module:$m, tool:$t, status:$st}'
        return 1
    fi

    storage_ensure_tool "$module" "$tool"
    local out_txt out_json
    out_txt=$(storage_tool_txt "$module" "$tool")
    out_json=$(storage_tool_json "$module" "$tool")

    # DNS: timeout dedicado (filtro crítico)
    local timeout_sec
    if [[ -n "$timeout_override" ]]; then
        timeout_sec="$timeout_override"
    elif [[ "$module" == "dns_resolution" ]]; then
        timeout_sec="${TIMEOUT_DNS:-${TIMEOUT_TOOL:-900}}"
    else
        timeout_sec="${TIMEOUT_TOOL:-900}"
    fi

    local max_retries="${RETRY_MAX:-1}"
    local base_delay="${RETRY_BASE_DELAY:-5}"
    local attempt=0
    local exit_code=1
    local started finished
    local stdout_file stderr_file
    _shm="/tmp"
    [[ -d /dev/shm && -w /dev/shm ]] && _shm=/dev/shm
    stdout_file=$(mktemp -p "$_shm" fw_out.XXXXXX)
    stderr_file=$(mktemp -p "$_shm" fw_err.XXXXXX)
    local key="${module}.${tool}"
    local start_epoch
    start_epoch=$(date +%s)
    started=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    storage_update_tool "$key" \
        --arg m "$module" --arg t "$tool" --arg ts "$started" \
        '.[$k] = {module:$m, tool:$t, status:"running", started:$ts, finished:null, elapsed_sec:0, found:0, lines:0}'
    events_emit "TOOL_START" "module=${module}" "tool=${tool}" "target=${TARGET_DOMAIN:-}"
    metrics_tool_start "$module" "$tool" 2>/dev/null || true

    while (( attempt <= max_retries )); do
        : > "$stdout_file"
        : > "$stderr_file"
        set +e
        # --foreground + KILL: encerra o grupo e reduz perda de flush
        timeout --foreground --signal=KILL --preserve-status "${timeout_sec}" \
            bash "$tool_script" "$input_file" "$stdout_file" "$stderr_file" \
            </dev/null \
            2>> "$stderr_file"
        exit_code=$?
        set -e

        if [[ $exit_code -eq 124 || $exit_code -eq 137 || $exit_code -eq 143 ]]; then
            log_warn "Tool ${tool} timeout/killed (exit=${exit_code}, ${timeout_sec}s) — preservando saída parcial"
            events_emit "TOOL_TIMEOUT" "module=${module}" "tool=${tool}" "exit=${exit_code}"
            break
        fi
        if [[ $exit_code -eq 0 ]]; then
            break
        fi
        if [[ $exit_code -eq 127 ]] || ! is_transient_error "$exit_code" "$(head -c 300 "$stderr_file" 2>/dev/null || true)"; then
            break
        fi
        ((attempt++)) || true
        if (( attempt > max_retries )); then
            break
        fi
        local delay=$(( base_delay * (2 ** (attempt - 1)) ))
        log_warn "Tool ${tool} falhou (tentativa ${attempt}/${max_retries}). Retry em ${delay}s"
        events_emit "TOOL_RETRY" "module=${module}" "tool=${tool}" "attempt=${attempt}"
        sleep "$delay"
    done

    finished=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local end_epoch elapsed_sec duration_ms
    end_epoch=$(date +%s)
    elapsed_sec=$(( end_epoch - start_epoch ))
    duration_ms=$(( elapsed_sec * 1000 ))

    # Preserva SEMPRE o que foi escrito (inclui timeout)
    if [[ -s "$stdout_file" ]]; then
        sort -u "$stdout_file" > "$out_txt"
    else
        : > "$out_txt"
    fi

    local lines=0
    [[ -f "$out_txt" ]] && lines=$(wc -l < "$out_txt" | tr -d ' ')

    local status="ok"
    local partial=false
    if [[ $exit_code -eq 124 || $exit_code -eq 137 || $exit_code -eq 143 ]]; then
        status="timeout"
        partial=true
    elif [[ $exit_code -ne 0 ]]; then
        status="error"
    fi

    _tool_runner_write_json "$out_json" "$tool" "$module" "${TARGET_DOMAIN:-unknown}" \
        "$started" "$finished" "$duration_ms" "$status" "$exit_code" \
        "$lines" "$stdout_file" "$stderr_file" "$attempt" "$partial"

    storage_update_tool "$key" \
        --arg m "$module" --arg t "$tool" --arg st "$status" \
        --arg ts "$finished" --argjson lines "$lines" --argjson elapsed "$elapsed_sec" \
        --argjson partial "$partial" \
        '.[$k] = ((.[$k] // {module:$m, tool:$t}) + {status:$st, finished:$ts, lines:$lines, elapsed_sec:$elapsed, found:$lines, partial:$partial})'

    storage_update_module "$module" \
        '.[$m].tools_finished = ((.[$m].tools_finished // 0) + 1)'

    events_emit "TOOL_END" "module=${module}" "tool=${tool}" "status=${status}" "lines=${lines}" "duration_ms=${duration_ms}"
    metrics_tool_end "$module" "$tool" "$status" "$duration_ms" "$lines" "$exit_code" "$attempt" 2>/dev/null || true

    rm -f "$stdout_file" "$stderr_file"

    if [[ "$status" == "ok" ]]; then
        log_ok "Tool ${tool} finalizada (${lines} linhas, ${elapsed_sec}s)"
    elif [[ "$status" == "timeout" ]]; then
        log_warn "Tool ${tool} timeout — ${lines} linhas parciais salvas (${elapsed_sec}s)"
    else
        log_warn "Tool ${tool} finalizada com status=${status} (exit=${exit_code}, lines=${lines})"
    fi
    return 0
}

_tool_runner_write_json() {
    local outfile="$1" tool="$2" module="$3" target="$4"
    local started="$5" finished="$6" duration_ms="$7" status="$8" exit_code="$9"
    local lines="${10}" stdout_file="${11}" stderr_file="${12}" retries="${13}"
    local partial="${14:-false}"
    local findings_file stderr_file_tmp
    findings_file=$(mktemp)
    stderr_file_tmp=$(mktemp)

    if [[ -s "$stdout_file" ]]; then
        jq -R -s -c '
            split("\n")
            | map(select(length > 0))
            | map({host: ., ips: [], url: null, ports: []})
        ' < "$stdout_file" > "$findings_file" 2>/dev/null || echo '[]' > "$findings_file"
    else
        echo '[]' > "$findings_file"
    fi

    head -c 1500 "$stderr_file" 2>/dev/null | tr '\n' ' ' > "$stderr_file_tmp" || : > "$stderr_file_tmp"

    jq -n \
        --arg tool "$tool" \
        --arg module "$module" \
        --arg target "$target" \
        --arg started "$started" \
        --arg finished "$finished" \
        --argjson duration_ms "$duration_ms" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson lines "$lines" \
        --argjson retries "$retries" \
        --argjson partial "$partial" \
        --slurpfile findings "$findings_file" \
        --rawfile stderr "$stderr_file_tmp" \
        '{
          schema_version: 1,
          tool: { name: $tool },
          module: { name: $module },
          target: { domain: $target },
          execution: {
            started_at: $started,
            finished_at: $finished,
            duration_ms: $duration_ms,
            retries: $retries,
            partial: $partial
          },
          status: {
            value: $status,
            exit_code: $exit_code
          },
          metrics: {
            lines: $lines,
            findings: ($findings[0] | length),
            stdout_lines: $lines
          },
          findings: $findings[0],
          errors: (if ($stderr | length) > 0 then [$stderr] else [] end),
          metadata: { partial: $partial }
        }' > "$outfile"

    rm -f "$findings_file" "$stderr_file_tmp"
}

export -f tool_run
