#!/usr/bin/env bash
# core/lib/run_state.sh
# Versão mínima + escrita atômica com flock

set -euo pipefail

_status_dir() {
    local domain="${TARGET_DOMAIN:-${DOMAIN:-unknown}}"
    echo "${ROOT_DIR}/results/${domain}/_status"
}

# ---------------------------------------------------------------------------
# Helper de escrita atômica com lock
# ---------------------------------------------------------------------------
_jq_write() {
    local file="$1"
    shift
    local dir lock tmp

    dir="$(dirname "$file")"
    lock="${dir}/.lock"
    mkdir -p "$dir"

    (
        flock -w 15 9 || exit 1
        [[ -f "$file" ]] || echo '{}' > "$file"
        tmp=$(mktemp "${file}.XXXXXX")
        if jq "$@" "$file" > "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$file"
        else
            rm -f "$tmp"
        fi
    ) 9>"$lock"
}

# ---------------------------------------------------------------------------
# Inicialização
# ---------------------------------------------------------------------------
status_init() {
    local domain="${1:-${TARGET_DOMAIN:-${DOMAIN:-}}}"
    [[ -n "$domain" ]] || return 1

    local dir
    dir="$(_status_dir)"
    mkdir -p "$dir"

    [[ -f "${dir}/run.json" ]]     || echo '{}' > "${dir}/run.json"
    [[ -f "${dir}/modules.json" ]] || echo '{}' > "${dir}/modules.json"
    [[ -f "${dir}/tools.json" ]]   || echo '{}' > "${dir}/tools.json"
    [[ -f "${dir}/events.log" ]]   || touch "${dir}/events.log"
}

status_run_start() {
    local domain="${1:-${TARGET_DOMAIN}}"
    local total="${2:-0}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local dir
    dir="$(_status_dir)"

    cat > "${dir}/run.json" <<EOF
{
  "target": "${domain}",
  "started": "${now}",
  "finished": null,
  "status": "running",
  "phase": 0,
  "modules_total": ${total},
  "modules_finished": 0
}
EOF
}

status_run_finish() {
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local dir
    dir="$(_status_dir)"

    _jq_write "${dir}/run.json" \
        --arg f "$now" \
        '.status = "finished" | .finished = $f'
}

status_set_phase() {
    local phase="$1"
    local dir
    dir="$(_status_dir)"

    _jq_write "${dir}/run.json" \
        --argjson p "$phase" \
        '.phase = $p'
}

# ---------------------------------------------------------------------------
# MODULE
# ---------------------------------------------------------------------------
status_module_start() {
    local mod="$1"
    local tools_total="${2:-0}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local dir
    dir="$(_status_dir)"

    _jq_write "${dir}/modules.json" \
        --arg m "$mod" --arg ts "$now" --argjson t "$tools_total" \
        '.[$m] = {status:"running", started:$ts, finished:null, found:0, tools_total:$t, tools_finished:0}'
}

status_module_end() {
    local mod="$1"
    local found="${2:-0}"
    local st="${3:-ok}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local dir
    dir="$(_status_dir)"

    found=$(echo "$found" | tr -d '[:space:]')
    [[ "$found" =~ ^[0-9]+$ ]] || found=0

    _jq_write "${dir}/modules.json" \
        --arg m "$mod" --arg ts "$now" --arg st "$st" --argjson f "$found" \
        '.[$m] = ((.[$m] // {}) + {status:$st, finished:$ts, found:$f})'

    _jq_write "${dir}/run.json" \
        '.modules_finished = ((.modules_finished // 0) + 1)'
}

status_module_error() {
    local mod="$1"
    local msg="${2:-error}"
    status_module_end "$mod" 0 "error"
}

# ---------------------------------------------------------------------------
# TOOL
# ---------------------------------------------------------------------------
status_tool_start() {
    local mod="$1"
    local tool="$2"
    local key="${mod}.${tool}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local dir
    dir="$(_status_dir)"

    _jq_write "${dir}/tools.json" \
        --arg k "$key" --arg m "$mod" --arg t "$tool" --arg ts "$now" \
        '.[$k] = {module:$m, tool:$t, status:"running", started:$ts, finished:null, elapsed_sec:0, found:0, lines:0}'
}

status_tool_end() {
    local mod="$1"
    local tool="$2"
    local st="${3:-ok}"
    local lines="${4:-0}"
    local elapsed="${5:-0}"
    local key="${mod}.${tool}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local dir
    dir="$(_status_dir)"

    lines=$(echo "$lines" | tr -d '[:space:]')
    elapsed=$(echo "$elapsed" | tr -d '[:space:]')
    [[ "$lines" =~ ^[0-9]+$ ]] || lines=0
    [[ "$elapsed" =~ ^[0-9]+$ ]] || elapsed=0

    _jq_write "${dir}/tools.json" \
        --arg k "$key" --arg m "$mod" --arg t "$tool" --arg st "$st" \
        --arg ts "$now" --argjson lines "$lines" --argjson elapsed "$elapsed" \
        '.[$k] = ((.[$k] // {module:$m, tool:$t}) + {status:$st, finished:$ts, lines:$lines, elapsed_sec:$elapsed, found:$lines})'

    _jq_write "${dir}/modules.json" \
        --arg m "$mod" \
        '.[$m].tools_finished = ((.[$m].tools_finished // 0) + 1)'
}

status_tool_error() {
    local mod="$1"
    local tool="$2"
    status_tool_end "$mod" "$tool" "error" 0 0
}
