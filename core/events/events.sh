#!/bin/bash
# core/events/events.sh
# Event Bus - único ponto de emissão de eventos.

set -euo pipefail

_EVENTS_FILE=""
_EVENTS_LOCK=""

events_init() {
    local domain="${1:?domínio obrigatório}"
    local status_dir
    status_dir=$(storage_status_dir "$domain")
    mkdir -p "${status_dir}"

    _EVENTS_FILE="${status_dir}/events.log"
    _EVENTS_LOCK="${status_dir}/.events.lock"

    [[ -f "${_EVENTS_FILE}" ]] || touch "${_EVENTS_FILE}"
}

events_emit() {
    local event_type="${1:?tipo de evento obrigatório}"
    shift
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    local extras=""
    for kv in "$@"; do
        extras="${extras} ${kv}"
    done

    [[ -n "${_EVENTS_FILE}" ]] || {
        echo "[events] events_init não foi chamado" >&2
        return 1
    }

    (
        flock -w 10 9 || exit 1
        printf '[%s] %s%s\n' "${ts}" "${event_type}" "${extras}" >> "${_EVENTS_FILE}"
    ) 9>"${_EVENTS_LOCK}"
}

events_tail() {
    local n="${1:-30}"
    [[ -n "${_EVENTS_FILE}" && -f "${_EVENTS_FILE}" ]] || return 0
    tail -n "${n}" "${_EVENTS_FILE}" 2>/dev/null || true
}

events_reset() {
    [[ -n "${_EVENTS_FILE}" ]] || return 0
    : > "${_EVENTS_FILE}"
}

export -f events_init events_emit events_tail events_reset
