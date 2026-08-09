cat > modules/reporting/parsers/exposure.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"; OUTPUT="${2:-}"; MODULE="${3:-exposure}"; TOOL="${4:-exposure}"
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
        | {
            source: {module: $module, tool: $tool, file: "", url: $u, host: $host, line: 0},
            host: $host, ips: [], url: (if $u != "" then $u else null end),
            ports: [], database_info: null,
            admin_panels: (
              if (.panel // .type // null) != null then
                [{type: (.panel // .type // "admin"), url: $u, version: (.version // ""), cves: []}]
              else [] end
            ),
            server_environment: null, http_details: null,
            discovered_endpoints: [], sensitive_data_leaks: null,
            possible_vulnerabilities: [], cloud_exposure: null, screenshot_path: null
          }
        | select(.host != "")
      ]
    }
' > "$OUTPUT"
echo "[parser:exposure] ${TOOL}: $(jq '.findings|length' "$OUTPUT") findings"
EOF
chmod +x modules/reporting/parsers/exposure.sh
