#!/bin/bash
# Detecta .git exposto (e sinais de .env) — sem dump pesado no storage

if [[ "${1:-}" == "--info" ]]; then
    echo "name=gitdumper"
    echo "version=1.0"
    echo "description=Detect exposed .git and sensitive files"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

command -v curl >/dev/null 2>&1 || { echo "curl missing" >>"$STDERR_FILE"; exit 127; }

: > "$STDOUT_FILE"
export GIT_TERMINAL_PROMPT=0

check_url() {
    local url="$1"
    local path="$2"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 \
        "${url}${path}" 2>>"$STDERR_FILE" || echo "000")
    echo "$code"
}

while IFS= read -r target || [[ -n "${target:-}" ]]; do
    [[ -z "${target// }" ]] && continue

    if [[ "$target" == http* ]]; then
        bases=("$target")
    else
        bases=("https://${target}" "http://${target}")
    fi

    for base in "${bases[@]}"; do
        base="${base%/}"
        code_git=$(check_url "$base" "/.git/HEAD")
        if [[ "$code_git" == "200" ]]; then
            echo "${base}/.git/HEAD [exposed]" >>"$STDOUT_FILE"
            # pistas de secrets sem baixar repo inteiro
            for p in "/.env" "/.git/config" "/config/.env" "/.env.backup"; do
                c=$(check_url "$base" "$p")
                if [[ "$c" == "200" ]]; then
                    echo "${base}${p} [status=${c}]" >>"$STDOUT_FILE"
                fi
            done
        fi
    done
done < "$INPUT_FILE"

sort -u -o "$STDOUT_FILE" "$STDOUT_FILE" 2>>"$STDERR_FILE" || true
exit 0
