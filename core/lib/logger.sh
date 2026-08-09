#!/bin/bash
# core/lib/logger.sh

set -euo pipefail

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local line="[${timestamp}] [${level}] ${msg}"

    if [[ "${ENABLE_LOG:-true}" == "true" ]]; then
        echo "${line}" | tee -a "${LOGS_DIR:-/tmp}/framework.log" >/dev/null
        case "${level}" in
            ERROR) echo -e "\033[0;31m${line}\033[0m" >&2 ;;
            WARN)  echo -e "\033[0;33m${line}\033[0m" ;;
            OK)    echo -e "\033[0;32m${line}\033[0m" ;;
            *)     echo "${line}" ;;
        esac
    else
        echo "${line}"
    fi
}

log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@"; }
log_error() { log "ERROR" "$@"; }
log_ok()    { log "OK"    "$@"; }
log_debug() { [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]] && log "DEBUG" "$@" || true; }
