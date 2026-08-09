#!/usr/bin/env bash
# modules/reporting/parsers/dns_resolution.sh

set -euo pipefail

INPUT="${1:-}"
OUTPUT="${2:-}"
MODULE="${3:-dns_resolution}"
TOOL="${4:-dns_resolution}"

[[ -f "$INPUT" ]] || { echo "[parser:dns_resolution] input inválido" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "[parser:dns_resolution] jq necessário" >&2; exit 1; }

TARGET=$(jq -r '.pipeline_metadata.target // "unknown"' "$INPUT" 2>/dev/null || echo "unknown")
TS=$(jq -r '.pipeline_metadata.timestamp // empty' "$INPUT" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# dnsx/puredns/shuffledns costumam gravar host e às vezes IPs
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
      | (.host // .url // "" | tostring) as $h
      | ($h | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
      | {
          source: {
            module: $module,
            tool: $tool,
            file: "",
            url: "",
            host: $host,
            line: 0
          },
          host: $host,
          ips: (
            if (.ips | type) == "array" and (.ips | length) > 0 then .ips
            elif (.ip | type) == "string" and .ip != "" then [.ip]
            else [] end
          ),
          url: null,
          ports: [],
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
      | select(.host != "")
    ]
  }
  ' > "$OUTPUT"

echo "[parser:dns_resolution] ${TOOL}: $(jq '.findings | length' "$OUTPUT") findings"
