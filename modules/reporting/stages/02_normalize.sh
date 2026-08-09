#!/usr/bin/env bash
# modules/reporting/stages/02_normalize.sh
# Etapa 02 – Normalize
# Cada JSON bruto passa pelo parser do seu módulo e sai no schema oficial.

set -euo pipefail

RESULTS_DIR="${1:-}"
WORKSPACE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSERS_DIR="${SCRIPT_DIR}/../parsers"
RAW_DIR="${WORKSPACE}/raw"
NORM_DIR="${WORKSPACE}/normalized"

mkdir -p "$NORM_DIR"

if [[ ! -d "$RAW_DIR" ]]; then
    echo "[normalize] ERRO: raw/ não existe. Rode 01_collect primeiro." >&2
    exit 1
fi

echo "[normalize] Normalizando JSONs de: ${RAW_DIR}"

normalized=0
skipped=0

# Mapeia prefixo do arquivo → parser
# Formato dos arquivos: modulo.json  ou  modulo__tool.json
for jsonf in "${RAW_DIR}"/*.json; do
    [[ -f "$jsonf" ]] || continue
    base=$(basename "$jsonf" .json)

    # Descobre o módulo
    if [[ "$base" == *"__"* ]]; then
        module="${base%%__*}"
        tool="${base#*__}"
    else
        module="$base"
        tool="$module"
    fi

    parser="${PARSERS_DIR}/${module}.sh"

    if [[ ! -x "$parser" ]]; then
        # Parser ainda não existe → copia bruto com aviso
        echo "[normalize] Parser ausente para '${module}' – copiando bruto"
        cp -f "$jsonf" "${NORM_DIR}/${base}.json"
        ((skipped++)) || true
        continue
    fi

    out="${NORM_DIR}/${base}.json"
    if "$parser" "$jsonf" "$out" "$module" "$tool"; then
        ((normalized++)) || true
    else
        echo "[normalize] ERRO no parser ${module} (${base})" >&2
        ((skipped++)) || true
    fi
done

total=$(find "$NORM_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
echo "[normalize] Normalizados : ${normalized}"
echo "[normalize] Sem parser   : ${skipped}"
echo "[normalize] Total saída  : ${total}"
echo "$total"
