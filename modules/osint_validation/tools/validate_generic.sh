#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_generic"; echo "version=1.0"; echo "description=Generic secret pattern filter"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
grep -iE \
  'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-|BEGIN (RSA |OPENSSH )?PRIVATE KEY|\.env|password\s*=|api[_-]?key\s*=' \
  "$IN" 2>>"$ERR" | sort -u >>"$OUT" || true
exit 0
