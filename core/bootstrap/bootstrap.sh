#!/bin/bash
# core/bootstrap/bootstrap.sh
# Bootstrap - Único ponto de inicialização.

[[ -n "${_BOOTSTRAP_LOADED:-}" ]] && return 0
_BOOTSTRAP_LOADED=1

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(cd "${BOOTSTRAP_DIR}/../.." && pwd)"

export CONFIG_DIR="${ROOT_DIR}/config"
export CORE_DIR="${ROOT_DIR}/core"
export LIB_DIR="${CORE_DIR}/lib"
export MODULES_DIR="${ROOT_DIR}/modules"
export RESULTS_DIR="${ROOT_DIR}/results"
export LOGS_DIR="${ROOT_DIR}/logs"
export CACHE_DIR="${ROOT_DIR}/cache"
export DATABASE_DIR="${ROOT_DIR}/database"
export TOOLS_DIR="${ROOT_DIR}/tools"
export TMP_DIR="${CACHE_DIR}/temporary"

export PATH="${PATH}:${HOME}/go/bin:$(go env GOPATH 2>/dev/null || echo '')/bin:${HOME}/.local/bin"

# shellcheck source=/dev/null
source "${CONFIG_DIR}/framework.conf"
# shellcheck source=/dev/null
[[ -f "${CONFIG_DIR}/api_keys.conf" ]] && source "${CONFIG_DIR}/api_keys.conf"
# shellcheck source=/dev/null
[[ -f "${CONFIG_DIR}/colors.conf" ]] && source "${CONFIG_DIR}/colors.conf"

mkdir -p \
    "${RESULTS_DIR}" \
    "${LOGS_DIR}" \
    "${CACHE_DIR}" \
    "${TMP_DIR}" \
    "${DATABASE_DIR}"

# shellcheck source=/dev/null
source "${LIB_DIR}/helpers.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/logger.sh"
# shellcheck source=/dev/null
source "${CORE_DIR}/storage/storage.sh"
# shellcheck source=/dev/null
source "${CORE_DIR}/events/events.sh"
# shellcheck source=/dev/null
# Metrics (Fase 3)
if [[ -f "${CORE_DIR}/metrics/metrics.sh" ]]; then
    # shellcheck source=/dev/null
    source "${CORE_DIR}/metrics/metrics.sh"
elif [[ -f "${ROOT_DIR}/core/metrics/metrics.sh" ]]; then
    # shellcheck source=/dev/null
    source "${ROOT_DIR}/core/metrics/metrics.sh"
fi
# shellcheck source=/dev/null
source "${CORE_DIR}/runtime/tool_runner.sh"

if ! command -v jq >/dev/null 2>&1; then
    echo "[BOOTSTRAP] AVISO: jq não encontrado. Funcionalidade JSON limitada." >&2
fi
if ! command -v timeout >/dev/null 2>&1; then
    echo "[BOOTSTRAP] ERRO: comando 'timeout' é obrigatório." >&2
    exit 1
fi

print_banner() {
    echo "=============================================="
    echo "  ${FRAMEWORK_NAME} v${FRAMEWORK_VERSION}"
    echo "=============================================="
}

export -f print_banner

# shellcheck source=/dev/null
[[ -f "${CORE_DIR}/scheduler/resolve_input.sh" ]] && source "${CORE_DIR}/scheduler/resolve_input.sh"
log_info "Bootstrap concluído | ROOT=${ROOT_DIR}"
