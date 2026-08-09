#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-osint}"; TOOL="${4:-osint}"
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
        | (.host // .domain // .url // .value // "" | tostring) as $raw
        | ($raw | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
        | {
            source: {
              module: $module, tool: $tool,
              file: (.file // .repo // ""),
              url: (.url // .link // ""),
              host: $host,
              line: (.line // 0)
            },
            host: (if $host != "" then $host else $target end),
            ips: (.ips // []),
            url: (.url // null),
            ports: [],
            database_info: null, admin_panels: [], server_environment: null,
            http_details: null, discovered_endpoints: [],
            sensitive_data_leaks: (
              if (.secret // .token // .password // .email // null) != null then
                {
                  credentials: (if .password then [{type: "secret", user: (.user // ""), password: .password}] else [] end),
                  tokens: (if .token then [{type: "secret", value: .token}] else [] end),
                  pii_found: {
                    emails: (if .email then [.email] else [] end),
                    cpfs: []
                  }
                }
              else null end
            ),
            possible_vulnerabilities: [],
            cloud_exposure: null, screenshot_path: null
          }
      ]
    }
' > "$OUTPUT"
echo "[parser:osint] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
