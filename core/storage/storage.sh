#!/bin/bash
# core/storage/storage.sh
# Storage Layer - ÚNICO componente que conhece caminhos.

set -euo pipefail

_STORAGE_DOMAIN=""

storage_init() {
    local domain="${1:?domínio obrigatório}"
    _STORAGE_DOMAIN="$domain"
    mkdir -p \
        "${ROOT_DIR}/results/${domain}/_status" \
        "${ROOT_DIR}/results/${domain}" \
        "${ROOT_DIR}/logs" \
        "${ROOT_DIR}/cache/temporary" \
        "${ROOT_DIR}/database"
}

storage_status_dir() {
    local domain="${1:-${_STORAGE_DOMAIN}}"
    echo "${ROOT_DIR}/results/${domain}/_status"
}

storage_module_dir() {
    local module="$1"
    local domain="${2:-${_STORAGE_DOMAIN}}"
    echo "${ROOT_DIR}/results/${domain}/${module}"
}

storage_tool_dir() {
    local module="$1"
    local tool="$2"
    local domain="${3:-${_STORAGE_DOMAIN}}"
    echo "${ROOT_DIR}/results/${domain}/${module}/tools/${tool}"
}

storage_tmp() {
    echo "${ROOT_DIR}/cache/temporary"
}

storage_log() {
    echo "${ROOT_DIR}/logs/framework.log"
}

storage_metrics_db() {
    local domain="${1:-${_STORAGE_DOMAIN:-${TARGET_DOMAIN}}}"
    echo "$(storage_status_dir "$domain")/metrics.db"
}

storage_ensure_module() {
    local module="$1"
    mkdir -p "$(storage_module_dir "$module")/tools"
}

storage_ensure_tool() {
    local module="$1"
    local tool="$2"
    mkdir -p "$(storage_tool_dir "$module" "$tool")"
}

storage_tool_txt() {
    local module="$1"
    local tool="$2"
    echo "$(storage_tool_dir "$module" "$tool")/result.txt"
}

storage_tool_json() {
    local module="$1"
    local tool="$2"
    echo "$(storage_tool_dir "$module" "$tool")/result.json"
}

storage_module_txt() {
    local module="$1"
    echo "$(storage_module_dir "$module")/module.txt"
}

storage_module_json() {
    local module="$1"
    echo "$(storage_module_dir "$module")/module.json"
}

_storage_jq_write() {
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
            return 1
        fi
    ) 9>"$lock"
}

storage_update_run() {
    local status_dir
    status_dir=$(storage_status_dir)
    _storage_jq_write "${status_dir}/run.json" "$@"
}

storage_update_module() {
    local module="$1"
    shift
    local status_dir
    status_dir=$(storage_status_dir)
    _storage_jq_write "${status_dir}/modules.json" --arg m "$module" "$@"
}

storage_update_tool() {
    local key="$1"
    shift
    local status_dir
    status_dir=$(storage_status_dir)
    _storage_jq_write "${status_dir}/tools.json" --arg k "$key" "$@"
}

storage_read() {
    local relative="$1"
    local status_dir
    status_dir=$(storage_status_dir)
    local file="${status_dir}/${relative}"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo '{}'
    fi
}

storage_ensure_base() {
    local domain="$1"
    storage_init "$domain"
    local status_dir
    status_dir=$(storage_status_dir)
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [[ ! -f "${status_dir}/run.json" ]]; then
        printf '{\n  "target": "%s",\n  "started": "%s",\n  "finished": null,\n  "status": "running",\n  "modules_total": 0,\n  "modules_finished": 0\n}\n' \
            "$domain" "$now" > "${status_dir}/run.json"
    fi
    [[ -f "${status_dir}/modules.json" ]] || echo '{}' > "${status_dir}/modules.json"
    [[ -f "${status_dir}/tools.json" ]] || echo '{}' > "${status_dir}/tools.json"
}

# Artefato extra do módulo (js.txt, api_endpoints.txt, etc.)
storage_write_artifact() {
    local module="$1"
    local filename="$2"
    local src="$3"
    local dest
    dest="$(storage_module_dir "$module")/${filename}"
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$src" ]]; then
        cp -f "$src" "$dest"
    else
        : > "$dest"
    fi
    echo "$dest"
}

# Limpeza de artefatos de runtime (cache e logs). Não toca em results/ nem na estrutura de database/.
storage_cleanup_runtime() {
    [[ -n "${ROOT_DIR:-}" ]] || return 0

    # Cache: remove conteúdo e recria temporary
    if [[ -d "${ROOT_DIR}/cache" ]]; then
        find "${ROOT_DIR}/cache" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
        mkdir -p "${ROOT_DIR}/cache/temporary" 2>/dev/null || true
    fi

    # Logs: remove arquivos .log e .pid (mantém a pasta)
    if [[ -d "${ROOT_DIR}/logs" ]]; then
        find "${ROOT_DIR}/logs" -type f \( -name "*.log" -o -name "*.pid" \) -delete 2>/dev/null || true
    fi
}

export -f storage_cleanup_runtime
export -f storage_init storage_status_dir storage_module_dir storage_tool_dir
export -f storage_tmp storage_log storage_metrics_db
export -f storage_ensure_module storage_ensure_tool
export -f storage_tool_txt storage_tool_json storage_module_txt storage_module_json
export -f storage_update_run storage_update_module storage_update_tool storage_read
export -f storage_ensure_base storage_write_artifact
