#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=whois"; echo "version=1.0"; echo "description=whois lookup"; exit 0
fi
INPUT_FILE="$1"; STDOUT_FILE="$2"; STDERR_FILE="$3"
command -v whois >/dev/null 2>&1 || { echo "whois missing" >>"$STDERR_FILE"; exit 127; }
while read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  { echo "=== ${domain} ==="; whois "$domain" 2>>"$STDERR_FILE" || true; echo; } >>"$STDOUT_FILE"
done < "$INPUT_FILE"
exit 0
