#!/usr/bin/env bash
# modules/reporting/stages/04_enrich.sh
# - Remove sources null
# - Resolve DNS e mantém só hosts que respondem (opcional via flag)
# - Preenche IPs faltantes
# - Gera versão limpa para export

set -euo pipefail

RESULTS_DIR="${1:-}"
WORKSPACE="${2:-}"

CORR="${WORKSPACE}/correlated/by_host.json"
ENRICH_DIR="${WORKSPACE}/enriched"
OUT="${ENRICH_DIR}/enriched.json"
LIVE_OUT="${ENRICH_DIR}/live_hosts.json"

# Se DNS_FILTER=0, não descarta hosts mortos (só preenche IPs)
DNS_FILTER="${DNS_FILTER:-1}"

mkdir -p "$ENRICH_DIR"

if [[ ! -f "$CORR" ]]; then
    echo "[enrich] ERRO: correlated/by_host.json não existe" >&2
    exit 1
fi

echo "[enrich] Limpando sources e preparando hosts..."

# 1. Limpeza básica com jq
jq '
  .findings = [
    .findings[]
    | .sources = ([ .sources[]? | select(. != null) ] | unique_by(.module + .tool))
    | .ips = ([ .ips[]? | select(. != null and . != "") ] | unique)
    | .admin_panels = ([ .admin_panels[]? | select(. != null) ])
    | .discovered_endpoints = ([ .discovered_endpoints[]? | select(. != null and . != "") ] | unique)
    | .possible_vulnerabilities = ([ .possible_vulnerabilities[]? | select(. != null) ])
  ]
  | .pipeline_metadata.tool = "pipeline_enrichment"
  | .pipeline_metadata.module = "reporting"
  | .pipeline_metadata.timestamp = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
' "$CORR" > "${ENRICH_DIR}/cleaned.json"

total_before=$(jq '.findings | length' "${ENRICH_DIR}/cleaned.json")
echo "[enrich] Hosts antes do DNS filter: ${total_before}"

if [[ "$DNS_FILTER" != "1" ]]; then
    cp "${ENRICH_DIR}/cleaned.json" "$OUT"
    echo "[enrich] DNS filter desligado – saída: ${OUT}"
    echo "$total_before"
    exit 0
fi

# 2. Resolver DNS e marcar quem responde
echo "[enrich] Resolvendo DNS (pode levar alguns segundos)..."

TMP_HOSTS=$(mktemp)
TMP_LIVE=$(mktemp)

jq -r '.findings[].host' "${ENRICH_DIR}/cleaned.json" | sort -u > "$TMP_HOSTS"

# Resolve em lote com dnsx se existir; senão usa getent/host
if command -v dnsx >/dev/null 2>&1; then
    dnsx -silent -a -resp -l "$TMP_HOSTS" 2>/dev/null \
      | awk '{print $1}' | sort -u > "$TMP_LIVE" || true
else
    while read -r h; do
        [[ -z "$h" ]] && continue
        if getent ahostsv4 "$h" >/dev/null 2>&1 || host "$h" >/dev/null 2>&1; then
            echo "$h"
        fi
    done < "$TMP_HOSTS" > "$TMP_LIVE"
fi

live_count=$(wc -l < "$TMP_LIVE" | tr -d ' ')
echo "[enrich] Hosts que resolvem DNS: ${live_count}"

# 3. Filtra só os vivos + tenta preencher IPs com dnsx -json se possível
if command -v dnsx >/dev/null 2>&1 && [[ -s "$TMP_LIVE" ]]; then
    DNSX_JSON=$(mktemp)
    dnsx -silent -a -resp -json -l "$TMP_LIVE" 2>/dev/null > "$DNSX_JSON" || true

    jq --slurpfile live <(jq -R -s 'split("\n") | map(select(length>0))' "$TMP_LIVE") \
       --slurpfile dnsx <(jq -s '.' "$DNSX_JSON" 2>/dev/null || echo '[]') \
    '
      ($live[0]) as $live_hosts
      | ($dnsx[0] | map({key: (.host // .Hostname // ""), value: .}) | from_entries) as $dnsmap
      | .findings = [
          .findings[]
          | select(.host as $h | $live_hosts | index($h))
          | .ips = (
              if (.ips | length) > 0 then .ips
              else
                ($dnsmap[.host].a // $dnsmap[.host].A // [])
              end
            )
        ]
    ' "${ENRICH_DIR}/cleaned.json" > "$OUT"
else
    # Fallback sem dnsx json
    jq --slurpfile live <(jq -R -s 'split("\n") | map(select(length>0))' "$TMP_LIVE") '
      ($live[0]) as $live_hosts
      | .findings = [ .findings[] | select(.host as $h | $live_hosts | index($h)) ]
    ' "${ENRICH_DIR}/cleaned.json" > "$OUT"
fi

total_after=$(jq '.findings | length' "$OUT" 2>/dev/null || echo 0)
echo "[enrich] Hosts após DNS filter: ${total_after}"
echo "[enrich] Saída: ${OUT}"

rm -f "$TMP_HOSTS" "$TMP_LIVE" "${DNSX_JSON:-}"
echo "$total_after"
