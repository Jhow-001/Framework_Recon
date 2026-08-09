#!/usr/bin/env bash
# modules/reporting/parsers/subdomains.sh
# Converte JSON de subdomains (módulo ou tool) → schema oficial com source

set -euo pipefail

INPUT="${1:-}"
OUTPUT="${2:-}"
MODULE="${3:-subdomains}"
TOOL="${4:-subdomains}"

[[ -f "$INPUT" ]] || { echo "[parser:subdomains] input inválido" >&2; exit 1; }

# Garante jq
command -v jq >/dev/null 2>&1 || { echo "[parser:subdomains] jq necessário" >&2; exit 1; }

TARGET=$(jq -r '.pipeline_metadata.target // "unknown"' "$INPUT" 2>/dev/null || echo "unknown")
TS=$(jq -r '.pipeline_metadata.timestamp // empty' "$INPUT" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# Transforma cada finding para o schema oficial
# - adiciona source obrigatório
# - mantém host
# - preenche campos vazios com defaults do schema completo
jq -n \
  --arg tool "$TOOL" \
  --arg module "$MODULE" \
  --arg target "$TARGET" \
  --arg ts "$TS" \
  --slurpfile src "$INPUT" \
  '
  ($src[0].findings // []) as $findings
  |
  {
    pipeline_metadata: {
      tool: $tool,
      module: $module,
      target: $target,
      timestamp: $ts
    },
    findings: [
      $findings[]
      | {
          source: {
            module: $module,
            tool: $tool,
            file: "",
            url: ( .url // "" | tostring ),
            host: ( .host // "" | tostring ),
            line: 0
          },
          host: ( .host // "" | tostring ),
          ips: ( .ips // [] ),
          url: ( .url // null ),
          ports: ( .ports // [] ),
          database_info: null,
          admin_panels: [],
          server_environment: null,
          http_details: null,
          discovered_endpoints: [],
          sensitive_data_leaks: null,
          possible_vulnerabilities: [],
          cloud_exposure: null,
          screenshot_path: null
        }
    ]
  }
  ' > "$OUTPUT"

echo "[parser:subdomains] ${TOOL}: $(jq '.findings | length' "$OUTPUT") findings"
