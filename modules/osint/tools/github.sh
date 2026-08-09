#!/bin/bash
# Busca código/repos no GitHub que citam o domínio (token free)

if [[ "${1:-}" == "--info" ]]; then
    echo "name=github"
    echo "version=1.0"
    echo "description=GitHub code search for domain"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

export GIT_TERMINAL_PROMPT=0
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
[[ -n "$TOKEN" ]] || { echo "GITHUB_TOKEN empty" >>"$STDERR_FILE"; exit 0; }

command -v curl >/dev/null 2>&1 || { echo "curl missing" >>"$STDERR_FILE"; exit 127; }
command -v jq >/dev/null 2>&1 || { echo "jq missing" >>"$STDERR_FILE"; exit 127; }

: > "$STDOUT_FILE"

while IFS= read -r domain || [[ -n "${domain:-}" ]]; do
    [[ -z "${domain// }" ]] && continue

    curl -sG "https://api.github.com/search/code" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --data-urlencode "q=${domain}" \
        --data-urlencode "per_page=30" \
        >>"$STDERR_FILE" 2>&1 \
        | jq -r '.items[]?.html_url // empty' 2>>"$STDERR_FILE"

    # Repos pelo nome/org aproximada
    org=$(echo "$domain" | awk -F. '{ if (NF>=2) print $(NF-1); else print $0 }')
    curl -sG "https://api.github.com/search/repositories" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        --data-urlencode "q=${org} OR ${domain}" \
        --data-urlencode "per_page=20" \
        2>>"$STDERR_FILE" \
        | jq -r '.items[]?.html_url // empty' 2>>"$STDERR_FILE"
done < "$INPUT_FILE" | sort -u >>"$STDOUT_FILE" || true

exit 0
