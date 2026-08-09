#!/bin/bash
# core/scheduler/resolve_input.sh
# Resolve referência de entrada do pipeline.conf para path real (ou DOMAIN/ALL).

set -euo pipefail

# Uso: resolve_input <ref> <domain> <results_base>
# Imprime: DOMAIN | ALL | caminho_do_arquivo | (vazio se ainda não existe)

resolve_input() {
    local ref="$1"
    local domain="$2"
    local results_base="$3"

    case "$ref" in
        DOMAIN)
            echo "DOMAIN"
            return 0
            ;;
        ALL)
            echo "ALL"
            return 0
            ;;
    esac

    # Procura arquivo de saída em results/<domínio>/**/<ref>
    local found
    found=$(find "$results_base" -type f -name "$ref" 2>/dev/null | head -n 1 || true)

    if [[ -n "$found" && -s "$found" ]]; then
        echo "$found"
        return 0
    fi

    # Ainda não pronto
    echo ""
    return 0
}

export -f resolve_input
