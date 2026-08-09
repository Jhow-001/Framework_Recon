#!/bin/bash
# Secrets via TruffleHog (GitHub org/user aproximado pelo domínio)
# Contrato: $1 input | $2 stdout | $3 stderr

if [[ "${1:-}" == "--info" ]]; then
    echo "name=trufflehog"
    echo "version=1.0"
    echo "description=TruffleHog GitHub secret scan"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
[[ -n "$TOKEN" ]] || { echo "GITHUB_TOKEN empty" >>"$STDERR_FILE"; exit 0; }

if ! command -v trufflehog >/dev/null 2>&1; then
    echo "trufflehog binary not found" >>"$STDERR_FILE"
    exit 127
fi

export GIT_TERMINAL_PROMPT=0
# TruffleHog usa o token do ambiente
export GITHUB_TOKEN="$TOKEN"
export GH_TOKEN="$TOKEN"

: > "$STDOUT_FILE"

while IFS= read -r domain || [[ -n "${domain:-}" ]]; do
    [[ -z "${domain// }" ]] && continue

    # org aproximada: example.com → example
    org=$(echo "$domain" | awk -F. '{ if (NF>=2) print $(NF-1); else print $0 }')

    # --results filtrado; saída só no stdout da tool
    # JSON lines se suportado; senão texto
    if trufflehog github --help 2>&1 | grep -q -- '--org'; then
        trufflehog github \
            --org="$org" \
            --token="$TOKEN" \
            --results=verified,unknown \
            --no-update \
            2>>"$STDERR_FILE" \
            | head -n 500 >>"$STDOUT_FILE" || true
    else
        # fallback genérico
        trufflehog github --org="$org" 2>>"$STDERR_FILE" \
            | head -n 500 >>"$STDOUT_FILE" || true
    fi
done < "$INPUT_FILE"

if [[ -s "$STDOUT_FILE" ]]; then
    sort -u -o "$STDOUT_FILE" "$STDOUT_FILE" 2>>"$STDERR_FILE" || true
fi

exit 0
