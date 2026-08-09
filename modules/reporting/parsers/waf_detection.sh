#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-waf_detection}"; TOOL="${4:-waf_detection}"
[[ -f "$INPUT" ]] || exit 1
command -v jq >/dev/null || exit 1

TARGET=$(jq -r '.pipeline_metadata.target // "unknown"' "$INPUT")
TS=$(jq -r '.pipeline_metadata.timestamp // empty' "$INPUT" || date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n --arg tool "$TOOL" --arg module "$MODULE" --arg target "$TARGET" --arg ts "$TS" --slurpfile src "$INPUT" '
  ($src[0].findings // []) as $f
  | {
      pipeline_metadata: {tool: $tool, module: $module, target: $target, timestamp: $ts},
      findings: [
        $f[]
        | (.host // .url // $target | tostring | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
        | {
            source: {module: $module, tool: $tool, file: "", url: (.url // ""), host: $host, line: 0},
            host: $host,
            ips: (.ips // []),
            url: (.url // null),
            ports: [],
            database_info: null, admin_panels: [],
            server_environment: {
              server_software: (.waf // .firewall // .detected // "WAF"),
              debug_mode: false,
              tech_stack: (if .waf then [.waf] elif .detected then [.detected] else [] end),
              ssl_issuer: null
            },
            http_details: null, discovered_endpoints: [],
            sensitive_data_leaks: null, possible_vulnerabilities: [],
            cloud_exposure: null, screenshot_path: null
          }
        | select(.host != "")
      ]
    }
' > "$OUTPUT"
echo "[parser:waf_detection] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
