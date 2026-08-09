#!/bin/bash
if [[ "${1:-}" == "--info" ]]; then
  echo "name=buckets"; echo "version=1.0"; echo "description=Generate bucket name candidates"; exit 0
fi
IN="$1"; OUT="$2"; ERR="$3"
: > "$OUT"
while IFS= read -r domain || [[ -n "${domain:-}" ]]; do
  [[ -z "${domain// }" ]] && continue
  base=$(echo "$domain" | cut -d'.' -f1)
  for suffix in "" "-backup" "-dev" "-staging" "-prod" "-assets" "-media" "-static" "-data" "-files" "-uploads"; do
    echo "${base}${suffix}"
  done
done < "$IN" | sort -u >>"$OUT"
exit 0
