#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-api}"; TOOL="${4:-api}"
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
        | (.url // .host // "" | tostring) as $u
        | ($u | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
        | ($u | capture("^https?://[^/]+(?<path>/.*)$")? | .path // "/") as $path
        | {
            source: {module: $module, tool: $tool, file: "", url: $u, host: $host, line: 0},
            host: $host, ips: [], url: (if $u != "" then $u else null end),
            ports: [], database_info: null, admin_panels: [], server_environment: null,
            http_details: null,
            discovered_endpoints: (if $path != "" and $path != "/" then [$path] else [] end),
            sensitive_data_leaks: null, possible_vulnerabilities: [],
            cloud_exposure: null, screenshot_path: null
          }
        | select(.host != "")
      ]
    }
' > "$OUTPUT"
echo "[parser:api] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
