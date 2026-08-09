#!/bin/bash
# core/lib/helpers.sh

require_bin() {
    local bin="$1"
    if ! command -v "$bin" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

ensure_dir() {
    mkdir -p "$1"
}

iso_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

epoch_now() {
    date +%s
}

is_transient_error() {
    local exit_code="$1"
    local stderr_snippet="${2:-}"

    case "$exit_code" in
        124|137|143) return 0 ;;
    esac

    if echo "$stderr_snippet" | grep -qiE 'timeout|connection refused|temporary failure|429|503|ssl handshake|network is unreachable|name resolution'; then
        return 0
    fi

    return 1
}
