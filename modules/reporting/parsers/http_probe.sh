#!/usr/bin/env bash
# modules/reporting/parsers/http_probe.sh
# Limpa a saída suja do httpx/webprobe e normaliza para o schema oficial

set -euo pipefail

INPUT="${1:-}"
OUTPUT="${2:-}"
MODULE="${3:-http_probe}"
TOOL="${4:-http_probe}"

[[ -f "$INPUT" ]] || { echo "[parser:http_probe] input inválido" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "[parser:http_probe] jq necessário" >&2; exit 1; }

TARGET=$(jq -r '.pipeline_metadata.target // "unknown"' "$INPUT" 2>/dev/null || echo "unknown")
TS=$(jq -r '.pipeline_metadata.timestamp // empty' "$INPUT" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# httpx atual grava algo como:
# "url": "https://beta.iana.org [200] [Title] [tech1,tech2]"
# Precisamos extrair: url limpa, status_code, title, tech_stack

jq -n \
  --arg tool "$TOOL" \
  --arg module "$MODULE" \
  --arg target "$TARGET" \
  --arg ts "$TS" \
  --slurpfile src "$INPUT" \
  '
  def parse_httpx_line:
    # Entrada típica: "https://host [200] [Title Here] [Tech1,Tech2]"
    . as $raw
    | ($raw | capture("^(?<url>https?://[^ \\[]+)"; "g") | .url) as $url
    | ($raw | capture("\\[(?<code>[0-9]+)\\]"; "g") | .code | tonumber?) as $code
    | ($raw | capture("\\[[0-9]+\\] \\[(?<title>[^\\]]*)\\]"; "g") | .title) as $title
    | ($raw | capture("\\[(?<tech>[A-Za-z0-9., _-]+)\\]$"; "g") | .tech) as $tech
    | {
        url: ($url // $raw),
        status_code: ($code // null),
        title: ($title // null),
        tech_stack: (
          if $tech then
            ($tech | split(",") | map(gsub("^ +| +$";"")) | map(select(length > 0)))
          else [] end
        )
      };

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
      | (.url // .host // "") as $raw_line
      | ($raw_line | parse_httpx_line) as $parsed
      | ($parsed.url | sub("^https?://"; "") | split("/")[0] | split(":")[0]) as $host
      | {
          source: {
            module: $module,
            tool: $tool,
            file: "",
            url: $parsed.url,
            host: $host,
            line: 0
          },
          host: $host,
          ips: (.ips // []),
          url: $parsed.url,
          ports: (.ports // []),
          database_info: null,
          admin_panels: [],
          server_environment: (
            if ($parsed.tech_stack | length) > 0 then
              {
                server_software: ($parsed.tech_stack[0] // null),
                debug_mode: false,
                tech_stack: $parsed.tech_stack,
                ssl_issuer: null
              }
            else null end
          ),
          http_details: {
            status_code: $parsed.status_code,
            title: $parsed.title
          },
          discovered_endpoints: [],
          sensitive_data_leaks: null,
          possible_vulnerabilities: [],
          cloud_exposure: null,
          screenshot_path: null
        }
    ]
  }
  ' > "$OUTPUT"

echo "[parser:http_probe] ${TOOL}: $(jq '.findings | length' "$OUTPUT") findings"
