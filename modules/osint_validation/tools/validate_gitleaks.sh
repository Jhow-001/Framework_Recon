#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=validate_gitleaks"; echo "version=1.0"; echo "description=Keep gitleaks-like secret lines"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
# Linhas que já vieram do gitleaks (repo | rule | file) ou padrões óbvios
grep -iE 'gitleaks|RuleID|\.env|aws_access|secret|password|api[_-]?key|token' "$IN" 2>>"$ERR" \
  | grep -vE '^#' | sort -u >>"$OUT" || true
exit 0
