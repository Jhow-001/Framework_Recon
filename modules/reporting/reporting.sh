#!/bin/bash
set -euo pipefail

DOMAIN="${1:-}"
[[ -n "$DOMAIN" ]] || { echo "Uso: $0 <dominio>"; exit 1; }

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
export ROOT_DIR
export VALIDATE_MAX="${VALIDATE_MAX:-40}"

# shellcheck source=/dev/null
[[ -f "${ROOT_DIR}/core/bootstrap/bootstrap.sh" ]] && source "${ROOT_DIR}/core/bootstrap/bootstrap.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "${ROOT_DIR}/modules/reporting/lib/classify.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/modules/reporting/lib/reclassify.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/modules/reporting/lib/render.sh"

RESULTS="${ROOT_DIR}/results/${DOMAIN}"
[[ -d "$RESULTS" ]] || { echo "Sem results para: $DOMAIN"; exit 1; }

OUT_DIR="${RESULTS}/report"
WORK="${OUT_DIR}/.work_classify"
rm -rf "$WORK"
mkdir -p "$WORK" "$OUT_DIR"

for s in CRITICAL HIGH MEDIUM LOW INFO; do
  : > "${WORK}/${s}.txt"
done
: > "${WORK}/_index.tsv"

log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"; }
log_ok()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $*"; }

log_info "Reporting V2 (conservative + validate) — ${DOMAIN}"

LIST="${WORK}/_files.list"
find "$RESULTS" -type f -name '*.txt' \
  ! -path '*/report/*' \
  ! -path '*/images/*' \
  ! -path '*/screenshots/*' \
  2>/dev/null | head -n 500 > "$LIST"

nfiles=$(wc -l < "$LIST" | tr -d ' ')
log_info "Arquivos .txt encontrados: ${nfiles}"

while IFS= read -r f; do
  [[ -f "$f" && -s "$f" ]] || continue
  rel="${f#"${RESULTS}/"}"
  src=$(echo "$rel" | sed 's|/|_|g; s|\.txt$||')
  if echo "$rel" | grep -qiE 'fuzzing|ffuf'; then
    head -n 1500 "$f" > "${WORK}/_slice.txt" || true
  else
    head -n 4000 "$f" > "${WORK}/_slice.txt" || true
  fi
  [[ -s "${WORK}/_slice.txt" ]] || continue
  classify_file "${WORK}/_slice.txt" "$src" "$WORK"
done < "$LIST"

for s in CRITICAL HIGH MEDIUM LOW INFO; do
  [[ -f "${WORK}/${s}.txt" ]] && sort -u -o "${WORK}/${s}.txt" "${WORK}/${s}.txt"
done

log_info "Counts pós-classify: C=$(wc -l < "${WORK}/CRITICAL.txt" | tr -d ' ') H=$(wc -l < "${WORK}/HIGH.txt" | tr -d ' ') M=$(wc -l < "${WORK}/MEDIUM.txt" | tr -d ' ') L=$(wc -l < "${WORK}/LOW.txt" | tr -d ' ') I=$(wc -l < "${WORK}/INFO.txt" | tr -d ' ')"

# Fase 2 — validação curl (não aborta o report)
set +e
reclassify_work "$WORK"
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  log_info "reclassify_work retornou ${rc} — seguindo com buckets atuais"
fi

# Polish HIGH (dedup / ruído)
# shellcheck source=/dev/null
source "${ROOT_DIR}/modules/reporting/lib/polish_high.sh"
polish_high "$WORK"

# Render — não aborta o script se jq falhar
set +e
render_report "$DOMAIN" "$WORK" "$OUT_DIR"
rc_render=$?
set -e

if [[ ! -f "${OUT_DIR}/alerts.txt" ]]; then
  log_info "render falhou (sem alerts.txt) rc=${rc_render}"
  exit 1
fi

log_ok "SUMMARY → ${OUT_DIR}/summary.md"
log_ok "FINDINGS → ${OUT_DIR}/findings.json"
log_ok "ALERTS → ${OUT_DIR}/alerts.txt"
log_ok "VALIDATED → ${OUT_DIR}/.work_classify/_validated.tsv"
log_ok "Reporting V2 concluído — ${DOMAIN}"
exit 0
