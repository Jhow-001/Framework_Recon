#!/usr/bin/env bash
# modules/reporting/stages/01_collect.sh
# Etapa 01 – Collect
# Responsabilidade única: encontrar e copiar todos os *.json relevantes
# para o workspace do reporting. Não interpreta nada.

set -euo pipefail

RESULTS_DIR="${1:-}"
WORKSPACE="${2:-}"

if [[ -z "$RESULTS_DIR" || ! -d "$RESULTS_DIR" ]]; then
    echo "[collect] ERRO: RESULTS_DIR inválido: ${RESULTS_DIR}" >&2
    exit 1
fi

if [[ -z "$WORKSPACE" ]]; then
    echo "[collect] ERRO: WORKSPACE não informado" >&2
    exit 1
fi

mkdir -p "${WORKSPACE}/raw"

echo "[collect] Coletando JSONs de: ${RESULTS_DIR}"

# Lista de módulos cujos JSONs devem ser coletados
# (screenshots fica de fora de propósito)
COLLECT_MODULES=(
    subdomains
    osint
    cloud
    dns_resolution
    http_probe
    ports_scan
    waf_detection
    crawling
    fuzzing 
    javascript
    api
    exposure
    access_control
    jwt_analysis
    osint_validation
    vulnerability
)

copied=0
skipped=0

for mod in "${COLLECT_MODULES[@]}"; do
    mod_dir="${RESULTS_DIR}/${mod}"
    [[ -d "$mod_dir" ]] || continue

    # JSON principal do módulo
    if [[ -f "${mod_dir}/${mod}.json" ]]; then
        cp -f "${mod_dir}/${mod}.json" "${WORKSPACE}/raw/${mod}.json"
        ((copied++)) || true
    fi

    # JSONs das tools (results_tools/)
    tools_dir="${mod_dir}/results_tools"
    if [[ -d "$tools_dir" ]]; then
        for jsonf in "${tools_dir}"/*.json; do
            [[ -f "$jsonf" ]] || continue
            base=$(basename "$jsonf")
            # Prefixo com o nome do módulo para evitar colisão
            cp -f "$jsonf" "${WORKSPACE}/raw/${mod}__${base}"
            ((copied++)) || true
        done
    fi
done

# Caso especial: ports_scan – preferir apenas nmap (se existir)
if [[ -f "${RESULTS_DIR}/ports_scan/results_tools/nmap.json" ]]; then
    cp -f "${RESULTS_DIR}/ports_scan/results_tools/nmap.json" \
          "${WORKSPACE}/raw/ports_scan__nmap.json"
fi

# Índice do que foi coletado
find "${WORKSPACE}/raw" -type f -name "*.json" 2>/dev/null | sort > "${WORKSPACE}/collect_index.txt"
total=$(wc -l < "${WORKSPACE}/collect_index.txt" | tr -d ' ')

echo "[collect] Arquivos copiados : ${copied}"
echo "[collect] Total no workspace: ${total}"
echo "[collect] Índice            : ${WORKSPACE}/collect_index.txt"

# Saída para o orquestrador
echo "$total"
