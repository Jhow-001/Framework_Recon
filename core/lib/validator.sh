#!/usr/bin/env bash
# core/lib/validator.sh

validate_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "Arquivo não encontrado: $file"
        exit 1
    fi
}
