#!/bin/bash
# core/runtime/module_runner.sh
# ModuleRunner V2 — serial | parallel | hybrid + module_finalize
set -euo pipefail

module_run() {
    local module="$1"
    local input_file="$2"

    local module_script="${MODULES_DIR}/${module}/${module}.sh"

    if [[ ! -f "$module_script" ]]; then
        log_error "Módulo não encontrado: ${module}"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$module_script"

    if ! declare -F module_tools >/dev/null 2>&1; then
        log_error "Módulo ${module} não implementa module_tools()"
        return 1
    fi

    storage_ensure_module "$module"

    local mode="parallel"
    if declare -F module_mode >/dev/null 2>&1; then
        mode=$(module_mode 2>/dev/null || echo "parallel")
    fi

    local tools_list
    tools_list=$(module_tools)
    local tools_total
    tools_total=$(echo "$tools_list" | wc -w | tr -d ' ')

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    storage_update_module "$module" \
        --arg ts "$now" --argjson t "$tools_total" \
        '.[$m] = {status:"running", started:$ts, finished:null, found:0, tools_total:$t, tools_finished:0}'

    events_emit "MODULE_START" "module=${module}" "tools_total=${tools_total}" "mode=${mode}"
    log_info "Módulo ${module} iniciado | modo=${mode} | tools=${tools_total}"

    case "$mode" in
        serial)
            _module_run_serial "$module" "$input_file" "$tools_list"
            ;;
        hybrid)
            _module_run_hybrid "$module" "$input_file"
            ;;
        parallel|*)
            _module_run_parallel "$module" "$input_file" "$tools_list"
            ;;
    esac

    # Merge final
    local module_txt module_json tools_dir total findings_file finished

    module_txt=$(storage_module_txt "$module")
    module_json=$(storage_module_json "$module")
    tools_dir="$(storage_module_dir "$module")/tools"

    cat "${tools_dir}"/*/result.txt 2>/dev/null | sort -u > "$module_txt" || : > "$module_txt"
    total=$(wc -l < "$module_txt" 2>/dev/null | tr -d ' ' || echo 0)
    total=${total:-0}

    if command -v jq >/dev/null 2>&1; then
        findings_file=$(mktemp)
        if [[ -s "$module_txt" ]]; then
            jq -R -s -c '
                split("\n")
                | map(select(length > 0))
                | map({host: ., ips: [], url: null, ports: []})
            ' < "$module_txt" > "$findings_file" 2>/dev/null || echo '[]' > "$findings_file"
        else
            echo '[]' > "$findings_file"
        fi

        jq -n \
            --arg module "$module" \
            --arg target "${TARGET_DOMAIN:-}" \
            --argjson total "$total" \
            --slurpfile findings "$findings_file" \
            '{
              schema_version: 1,
              module: { name: $module },
              target: { domain: $target },
              metrics: { findings: $total },
              findings: $findings[0]
            }' > "$module_json"

        rm -f "$findings_file"
    fi

    # Classificação / artefatos extras (opcional — ex.: crawling)
    if declare -F module_finalize >/dev/null 2>&1; then
        log_info "module_finalize ${module}"
        module_finalize "$module_txt" || log_warn "module_finalize ${module} falhou (ignorado)"
    fi

    # Nome canônico do pipeline
    if declare -F module_output_name >/dev/null 2>&1; then
        local out_name
        out_name=$(module_output_name 2>/dev/null || true)
        if [[ -n "${out_name:-}" ]]; then
            cp -f "$module_txt" "$(storage_module_dir "$module")/${out_name}"
        fi
    fi

    finished=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    storage_update_module "$module" \
        --arg ts "$finished" --argjson f "$total" \
        '.[$m] = ((.[$m] // {}) + {status:"ok", finished:$ts, found:$f})'

    storage_update_run \
        '.modules_finished = ((.modules_finished // 0) + 1)'

    events_emit "MODULE_END" "module=${module}" "findings=${total}"
    metrics_module_end "$module" "ok" "$total" 2>/dev/null || true
    log_ok "Módulo ${module} finalizado | ${total} findings"
}

_module_run_serial() {
    local module="$1"
    local input_file="$2"
    local tools_list="$3"
    local tool
    for tool in $tools_list; do
        log_info "  → [serial] ${tool}"
        tool_run "$module" "$tool" "$input_file" || true
    done
}

_module_run_parallel() {
    local module="$1"
    local input_file="$2"
    local tools_list="$3"
    local tool pids=()

    for tool in $tools_list; do
        log_info "  → [parallel] ${tool}"
        tool_run "$module" "$tool" "$input_file" &
        pids+=($!)
    done

    local pid
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
}

_module_run_hybrid() {
    local module="$1"
    local input_file="$2"

    if ! declare -F module_tool_groups >/dev/null 2>&1; then
        log_warn "Módulo ${module} em hybrid sem module_tool_groups(); caindo para parallel"
        _module_run_parallel "$module" "$input_file" "$(module_tools)"
        return 0
    fi

    local -a groups=()
    local line group_tools tool pids pid rt
    local group_num=0
    local current_input="$input_file"
    local group_merge

    while IFS= read -r line || [[ -n "${line:-}" ]]; do
        [[ -z "${line// }" ]] && continue
        groups+=("$line")
    done < <(module_tool_groups)

    log_info "  → [hybrid] grupos planejados: ${#groups[@]} (${groups[*]})"

    if [[ ${#groups[@]} -eq 0 ]]; then
        log_warn "module_tool_groups() vazio"
        return 0
    fi

    for line in "${groups[@]}"; do
        group_num=$((group_num + 1))
        group_tools="$line"
        pids=()

        log_info "  → [hybrid] grupo ${group_num}/${#groups[@]}: ${group_tools} (input=$(basename "$current_input"))"

        for tool in $group_tools; do
            log_info "     • ${tool}"
            tool_run "$module" "$tool" "$current_input" &
            pids+=($!)
        done

        for pid in "${pids[@]+"${pids[@]}"}"; do
            wait "$pid" || true
        done

        group_merge=$(mktemp)
        : > "$group_merge"
        for tool in $group_tools; do
            rt="$(storage_tool_txt "$module" "$tool" 2>/dev/null || true)"
            [[ -n "$rt" && -s "$rt" ]] && cat "$rt" >> "$group_merge" || true
        done

        if [[ -s "$group_merge" ]]; then
            sort -u -o "$group_merge" "$group_merge" || true
            current_input="$group_merge"
            log_info "  → [hybrid] merge grupo ${group_num}: $(wc -l < "$group_merge" | tr -d ' ') linhas → próximo input"
        else
            rm -f "$group_merge"
            log_warn "  → [hybrid] grupo ${group_num} sem saída; mantém input anterior"
        fi
    done
}

export -f module_run
