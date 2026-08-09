#!/bin/bash
# Secrets em repos públicos relacionados ao domínio (clone shallow + scan)

if [[ "${1:-}" == "--info" ]]; then
    echo "name=gitleaks"
    echo "version=1.0"
    echo "description=Scan candidate repos for secrets"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
[[ -n "$TOKEN" ]] || { echo "GITHUB_TOKEN empty" >>"$STDERR_FILE"; exit 0; }

command -v gitleaks >/dev/null 2>&1 || { echo "gitleaks missing" >>"$STDERR_FILE"; exit 127; }
command -v git >/dev/null 2>&1 || { echo "git missing" >>"$STDERR_FILE"; exit 127; }
command -v curl >/dev/null 2>&1 || exit 127
command -v jq >/dev/null 2>&1 || exit 127

: > "$STDOUT_FILE"
export GIT_TERMINAL_PROMPT=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Descobre até N repos via API e scaneia
while IFS= read -r domain || [[ -n "${domain:-}" ]]; do
    [[ -z "${domain// }" ]] && continue
    org=$(echo "$domain" | awk -F. '{ if (NF>=2) print $(NF-1); else print $0 }')

    mapfile -t repos < <(
        curl -sG "https://api.github.com/search/repositories" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            --data-urlencode "q=${org}" \
            --data-urlencode "per_page=5" \
            2>>"$STDERR_FILE" \
        | jq -r '.items[]?.clone_url // empty' 2>>"$STDERR_FILE"
    )

    for repo in "${repos[@]:-}"; do
        [[ -z "$repo" ]] && continue
        name=$(basename "$repo" .git)
        dest="${TMP}/${name}"
        if git clone --depth 1 "$repo" "$dest" >>"$STDERR_FILE" 2>&1; then
            report="${TMP}/${name}_gl.json"
            gitleaks detect --source "$dest" --no-banner \
                --report-format json --report-path "$report" \
                >>"$STDERR_FILE" 2>&1 || true
            if [[ -s "$report" ]]; then
                jq -r --arg repo "$repo" \
                  '.[]? | "\($repo) | \(.RuleID // .Description // "secret") | \(.File // "")"' \
                  "$report" 2>>"$STDERR_FILE" >>"$STDOUT_FILE" || true
            fi
            rm -rf "$dest"
        fi
    done
done < "$INPUT_FILE"

sort -u -o "$STDOUT_FILE" "$STDOUT_FILE" 2>>"$STDERR_FILE" || true
exit 0
