#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-cloud}"; TOOL="${4:-cloud}"
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
        | (.host // .bucket // .url // $target | tostring) as $raw
        | ($raw | sub("^https?://"; "") | split("/")[0]) as $host
        | {
            source: {module: $module, tool: $tool, file: "", url: (.url // .bucket // ""), host: $host, line: 0},
            host: $host,
            ips: [],
            url: (.url // null),
            ports: [],
            database_info: null, admin_panels: [], server_environment: null,
            http_details: null, discovered_endpoints: [],
            sensitive_data_leaks: null,
            possible_vulnerabilities: [],
            cloud_exposure: {
              buckets_exposed: [
                {
                  provider: (.provider // "unknown"),
                  where: (.url // .bucket // $raw),
                  count: 1,
                  permission: (.permission // .acl // "unknown")
                }
              ]
            },
            screenshot_path: null
          }
      ]
    }
' > "$OUTPUT"
echo "[parser:cloud] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
