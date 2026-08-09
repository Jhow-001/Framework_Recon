#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-access_control}"; TOOL="${4:-access_control}"
[[ -f "$INPUT" ]] || exit 1
command -v jq >/dev/null || exit 1

TARGET=$(jq -r '.pipeline_metadata.target // "unknown"' "$INPUT")
TS=$(jq -r '.pipeline_metadata.timestamp // empty' "$INPUT" || date -u +"%Y-%m-%dT%H:%M:%SZ")

# tool name vira o tipo (bola, idor, bac, nuclei_access...)
VULN_TYPE=$(echo "$TOOL" | tr '[:lower:]' '[:upper:]' | sed 's/_SCANNER//;s/_SCAN//')

jq -n --arg tool "$TOOL" --arg module "$MODULE" --arg target "$TARGET" --arg ts "$TS" --arg vtype "$VULN_TYPE" --slurpfile src "$INPUT" '
  ($src[0].findings // []) as $f
  | {
      pipeline_metadata: {tool: $tool, module: $module, target: $target, timestamp: $ts},
      findings: [
        $f[]
        | (.host // .url // "" | tostring | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
        | (.url // .where // .path // "") as $where
        | {
            source: {module: $module, tool: $tool, file: "", url: ($where|tostring), host: $host, line: 0},
            host: $host,
            ips: (.ips // []),
            url: (if ($where|tostring) != "" then ($where|tostring) else null end),
            ports: [],
            database_info: null, admin_panels: [], server_environment: null,
            http_details: null, discovered_endpoints: [],
            sensitive_data_leaks: null,
            possible_vulnerabilities: [
              {
                type: (.type // $vtype // "ACCESS_CONTROL"),
                severity: (.severity // "Medium"),
                where: ($where|tostring),
                count: (.count // 1)
              }
            ],
            cloud_exposure: null, screenshot_path: null
          }
        | select(.host != "" or (.possible_vulnerabilities[0].where != ""))
      ]
    }
' > "$OUTPUT"
echo "[parser:access_control] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
