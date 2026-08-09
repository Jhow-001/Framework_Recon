#!/usr/bin/env bash
# core/lib/json_out.sh
# Helpers para saída JSON padronizada

json_iso_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# json_write_tool <outfile> <tool> <module> <target> <findings_json_array>
json_write_tool() {
    local outfile="$1"
    local tool="$2"
    local module="$3"
    local target="$4"
    local findings="${5:-[]}"
    local ts
    ts=$(json_iso_now)

    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg tool "$tool" \
            --arg module "$module" \
            --arg target "$target" \
            --arg ts "$ts" \
            --argjson findings "$findings" \
            '{
              pipeline_metadata: {
                tool: $tool,
                module: $module,
                target: $target,
                timestamp: $ts
              },
              findings: $findings
            }' > "$outfile"
    else
        printf '{"pipeline_metadata":{"tool":"%s","module":"%s","target":"%s","timestamp":"%s"},"findings":%s}\n' \
            "$tool" "$module" "$target" "$ts" "$findings" > "$outfile"
    fi
}

# Linhas de host → findings JSON
json_findings_from_hosts() {
    local file="$1"
    if [[ ! -s "$file" ]] || ! command -v jq >/dev/null 2>&1; then
        echo '[]'
        return
    fi
    jq -R -s -c '
      split("\n")
      | map(select(length > 0))
      | map({host: ., ips: [], url: null, ports: []})
    ' < "$file"
}

# Linhas de URL → findings JSON
json_findings_from_urls() {
    local file="$1"
    if [[ ! -s "$file" ]] || ! command -v jq >/dev/null 2>&1; then
        echo '[]'
        return
    fi
    jq -R -s -c '
      split("\n")
      | map(select(length > 0))
      | map({
          url: .,
          host: (sub("^https?://";"") | split("/")[0] | split(":")[0]),
          ips: [],
          ports: []
        })
    ' < "$file"
}

# host:port → findings JSON
json_findings_from_hostports() {
    local file="$1"
    if [[ ! -s "$file" ]] || ! command -v jq >/dev/null 2>&1; then
        echo '[]'
        return
    fi
    jq -R -s -c '
      split("\n")
      | map(select(length > 0))
      | map(
          if test(":") then
            capture("(?<host>[^:]+):(?<port>[0-9]+)")
            | {host: .host, ips: [], url: null, ports: [{port: (.port|tonumber), protocol: "tcp", state: "open"}]}
          else
            {host: ., ips: [], url: null, ports: []}
          end
        )
    ' < "$file"
}
