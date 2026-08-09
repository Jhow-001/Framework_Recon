#!/usr/bin/env bash
# ports_scan – preferir nmap; aceitar naabu/masscan/rustscan como fallback de portas
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-ports_scan}"; TOOL="${4:-ports_scan}"
[[ -f "$INPUT" ]] || exit 1
command -v jq >/dev/null || exit 1

TARGET=$(jq -r '.pipeline_metadata.target // "unknown"' "$INPUT")
TS=$(jq -r '.pipeline_metadata.timestamp // empty' "$INPUT" || date -u +"%Y-%m-%dT%H:%M:%SZ")

# Se for tool intermediária e existir nmap no mesmo lote, ainda normalizamos
# (o correlate faz o merge por host)
jq -n --arg tool "$TOOL" --arg module "$MODULE" --arg target "$TARGET" --arg ts "$TS" --slurpfile src "$INPUT" '
  def to_port:
    if type == "number" then {port: ., protocol: "tcp", state: "open", service: "", version: "", cves: []}
    elif type == "object" then
      {
        port: (.port // .Port // 0 | tonumber),
        protocol: (.protocol // .Protocol // "tcp"),
        state: (.state // .State // "open"),
        service: (.service // .Service // ""),
        version: (.version // .Version // ""),
        cves: (.cves // [])
      }
    else empty end;

  ($src[0].findings // []) as $f
  | {
      pipeline_metadata: {tool: $tool, module: $module, target: $target, timestamp: $ts},
      findings: [
        $f[]
        | (.host // .ip // .url // "" | tostring | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
        | select($host != "")
        | {
            source: {module: $module, tool: $tool, file: "", url: "", host: $host, line: 0},
            host: $host,
            ips: (if (.ips|type)=="array" then .ips elif .ip then [.ip] else [] end),
            url: null,
            ports: (
              if (.ports|type)=="array" and (.ports|length)>0 then [.ports[] | to_port]
              elif .port then [.port | to_port]
              else [] end
            ),
            database_info: null, admin_panels: [], server_environment: null,
            http_details: null, discovered_endpoints: [], sensitive_data_leaks: null,
            possible_vulnerabilities: [], cloud_exposure: null, screenshot_path: null
          }
      ]
    }
' > "$OUTPUT"
echo "[parser:ports_scan] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
