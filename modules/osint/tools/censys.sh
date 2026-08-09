#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=censys"; echo "version=1.0"; echo "description=Censys subdomains"; exit 0
fi
INPUT_FILE="$1"; STDOUT_FILE="$2"; STDERR_FILE="$3"
API_ID="${CENSYS_API_ID:-}"; API_SECRET="${CENSYS_API_KEY:-${CENSYS_SECRET:-}}"
[[ -n "$API_ID" && -n "$API_SECRET" ]] || exit 0
command -v censys >/dev/null 2>&1 || exit 127
export CENSYS_API_ID="$API_ID" CENSYS_API_SECRET="$API_SECRET"
while read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  censys subdomains "$domain" 2>>"$STDERR_FILE" || true
  censys search "names: ${domain}" --index-type hosts --pages 1 2>>"$STDERR_FILE" || true
done < "$INPUT_FILE" \
  | sed 's/\\n/\n/g' \
  | grep -E '^[A-Za-z0-9._-]+(\.[A-Za-z0-9._-]+)+$' \
  | tr '[:upper:]' '[:lower:]' | sort -u >>"$STDOUT_FILE" || true
exit 0
