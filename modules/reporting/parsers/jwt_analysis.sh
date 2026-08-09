#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-jwt_analysis}"; TOOL="${4:-jwt_analysis}"
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
        | (.host // .url // "" | tostring | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
        | (.url // .source_url // .file // "") as $src_url
        | {
            source: {
              module: $module, tool: $tool,
              file: (.file // .source_file // ""),
              url: ($src_url | tostring),
              host: $host,
              line: (.line // 0)
            },
            host: $host,
            ips: (.ips // []),
            url: (if $src_url != "" then $src_url else null end),
            ports: [],
            database_info: null, admin_panels: [], server_environment: null,
            http_details: null, discovered_endpoints: [],
            sensitive_data_leaks: {
              credentials: [],
              tokens: [
                {
                  type: (.type // "JWT"),
                  value: (.token // .value // .jwt // .encoded // ""),
                  decoding: (.decoding // .decoded // null),
                  source: {
                    module: $module, tool: $tool,
                    url: ($src_url | tostring),
                    file: (.file // ""),
                    line: (.line // 0)
                  }
                }
                | select(.value != "")
              ],
              pii_found: {emails: [], cpfs: []}
            },
            possible_vulnerabilities: [],
            cloud_exposure: null, screenshot_path: null
          }
        | select(.host != "" or (.sensitive_data_leaks.tokens|length) > 0)
      ]
    }
' > "$OUTPUT"
echo "[parser:jwt_analysis] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
