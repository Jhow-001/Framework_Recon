#!/usr/bin/env bash
# modules/reporting/stages/05_export.sh
# Gera o report.json final no schema oficial completo

set -euo pipefail

RESULTS_DIR="${1:-}"
WORKSPACE="${2:-}"

ENRICHED="${WORKSPACE}/enriched/enriched.json"
REPORT_DIR="${RESULTS_DIR}/reporting"
OUT="${REPORT_DIR}/report.json"
SUMMARY="${REPORT_DIR}/summary.json"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$ENRICHED" ]]; then
    echo "[export] ERRO: enriched.json não existe. Rode 04_enrich primeiro." >&2
    exit 1
fi

DOMAIN=$(basename "$RESULTS_DIR")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Tenta pegar time_start do run.json
START=$(jq -r '.started // empty' "${RESULTS_DIR}/_status/run.json" 2>/dev/null || true)
[[ -z "$START" ]] && START="$NOW"

echo "[export] Gerando report final..."

jq \
  --arg target "$DOMAIN" \
  --arg ts "$NOW" \
  --arg start "$START" \
  --arg finish "$NOW" \
  '
  {
    pipeline_metadata: {
      tool: "pipeline_enrichment",
      target: $target,
      timestamp: $ts,
      time_start: $start,
      time_finish: $finish
    },
    findings: [
      .findings[]
      | {
          host: .host,
          ips: (.ips // []),
          url: .url,
          ports: (.ports // []),
          database_info: .database_info,
          admin_panels: (.admin_panels // []),
          server_environment: .server_environment,
          http_details: .http_details,
          discovered_endpoints: (.discovered_endpoints // []),
          sensitive_data_leaks: .sensitive_data_leaks,
          possible_vulnerabilities: (.possible_vulnerabilities // []),
          cloud_exposure: .cloud_exposure,
          screenshot_path: .screenshot_path,
          # provenance obrigatório
          sources: (.sources // [])
        }
    ]
  }
  ' "$ENRICHED" > "$OUT"

# Summary rápido
jq \
  --arg target "$DOMAIN" \
  --arg ts "$NOW" \
  '
  {
    target: $target,
    generated_at: $ts,
    total_hosts: (.findings | length),
    hosts_with_http: ([.findings[] | select(.http_details != null)] | length),
    hosts_with_ips: ([.findings[] | select((.ips | length) > 0)] | length),
    total_ports: ([.findings[].ports[]?] | length),
    total_vulns: ([.findings[].possible_vulnerabilities[]?] | length),
    total_secrets: (
      [.findings[].sensitive_data_leaks.tokens[]?, .findings[].sensitive_data_leaks.credentials[]?] | length
    )
  }
  ' "$OUT" > "$SUMMARY"

total=$(jq '.findings | length' "$OUT")
echo "[export] Report : ${OUT}"
echo "[export] Summary: ${SUMMARY}"
echo "[export] Hosts  : ${total}"
echo "$total"
