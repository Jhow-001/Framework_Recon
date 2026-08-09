#!/bin/bash
# auth.sh — saída: open|auth_required|unknown|fail
validate_auth() {
  local url="$1"
  [[ -z "$url" || "$url" != http* ]] && { echo "unknown"; return 0; }
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -A "Mozilla/5.0 (compatible; ReconFramework/2.0)" \
    --connect-timeout 5 --max-time 8 \
    -L --max-redirs 2 "$url" 2>/dev/null) || code="000"
  case "$code" in
    401|403) echo "auth_required" ;;
    200|201|204|301|302) echo "open" ;;
    000) echo "fail" ;;
    *) echo "unknown" ;;
  esac
}
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f validate_auth 2>/dev/null || true
fi
