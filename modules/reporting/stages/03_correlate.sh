#!/usr/bin/env bash
# modules/reporting/stages/03_correlate.sh
# Junta todos os findings normalizados por ativo (host)

set -euo pipefail

RESULTS_DIR="${1:-}"
WORKSPACE="${2:-}"

NORM_DIR="${WORKSPACE}/normalized"
CORR_DIR="${WORKSPACE}/correlated"
OUT="${CORR_DIR}/by_host.json"

mkdir -p "$CORR_DIR"

if [[ ! -d "$NORM_DIR" ]]; then
    echo "[correlate] ERRO: normalized/ não existe. Rode 02_normalize primeiro." >&2
    exit 1
fi

echo "[correlate] Correlacionando findings por host..."

# Junta todos os findings de todos os JSONs normalizados
# e agrupa por host
jq -s '
  # Flatten all findings from all files
  [ .[] | .findings[]? ] as $all

  # Group by host
  | ($all | group_by(.host) | map({
      host: .[0].host,
      # Merge sources
      sources: [ .[].source ] | unique,
      # Merge IPs
      ips: [ .[].ips[]? ] | unique,
      # Prefer non-null url
      url: ([ .[].url | select(. != null and . != "") ] | first // null),
      # Merge ports
      ports: [ .[].ports[]? ] | unique_by(.port // .),
      # Merge http_details (prefer the one with status_code)
      http_details: ([ .[].http_details | select(. != null) ] | first // null),
      # Merge server_environment
      server_environment: ([ .[].server_environment | select(. != null) ] | first // null),
      # Merge other arrays
      admin_panels: [ .[].admin_panels[]? ],
      discovered_endpoints: [ .[].discovered_endpoints[]? ] | unique,
      possible_vulnerabilities: [ .[].possible_vulnerabilities[]? ],
      # Sensitive data
      sensitive_data_leaks: (
        [ .[].sensitive_data_leaks | select(. != null) ]
        | if length == 0 then null else
          {
            credentials: [ .[].credentials[]? ],
            tokens: [ .[].tokens[]? ],
            pii_found: {
              emails: [ .[].pii_found.emails[]? ] | unique,
              cpfs: [ .[].pii_found.cpfs[]? ] | unique
            }
          }
        end
      ),
      cloud_exposure: ([ .[].cloud_exposure | select(. != null) ] | first // null),
      database_info: ([ .[].database_info | select(. != null) ] | first // null),
      screenshot_path: ([ .[].screenshot_path | select(. != null) ] | first // null)
    }))
  | {
      pipeline_metadata: {
        tool: "pipeline_enrichment",
        module: "reporting",
        target: ($all[0].source.host // "unknown" | split(".") | .[-2:] | join(".")),
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
      },
      findings: .
    }
' "${NORM_DIR}"/*.json > "$OUT" 2>/dev/null || {
    # Fallback se algum JSON estiver vazio/inválido
    jq -s '[ .[] | select(.findings != null) ] | [ .[].findings[] ] | {pipeline_metadata:{tool:"pipeline_enrichment",module:"reporting",timestamp:(now|strftime("%Y-%m-%dT%H:%M:%SZ"))}, findings: .}' \
      "${NORM_DIR}"/*.json > "$OUT"
}

total=$(jq '.findings | length' "$OUT" 2>/dev/null || echo 0)
echo "[correlate] Hosts únicos correlacionados: ${total}"
echo "[correlate] Saída: ${OUT}"
echo "$total"
