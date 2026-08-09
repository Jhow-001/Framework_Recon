#!/bin/bash
# polish_high.sh — dedup host/porta e reduz ruído residual no HIGH

polish_high() {
  local work="$1"
  local high="${work}/HIGH.txt"
  [[ -f "$high" && -s "$high" ]] || return 0

  local tmp
  tmp=$(mktemp)

  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    [[ -z "${line// }" ]] && continue

    # descarta lixo de scanner que ainda tenha passado
    echo "$line" | grep -qiE 'Nmap scan|ssl-cert:|Subject Alternative|None \(None\)|healthcare' && continue

    # normaliza: extrai host
    local host=""
    if echo "$line" | grep -qE 'https?://'; then
      host=$(echo "$line" | sed -E 's|https?://([^/:]+).*|\1|')
    else
      host=$(echo "$line" | sed -E 's|:.*||; s|[[:space:]].*||')
    fi
    host=$(echo "$host" | tr '[:upper:]' '[:lower:]')

    # porta implícita 80/443 vira só host (dedup)
    local norm="$line"
    if echo "$line" | grep -qE ':(80|443)(/|$|[[:space:]])'; then
      norm="$host"
    fi
    # host:8080 mantém porta
    if echo "$line" | grep -qE ':(8080|8443|3000|5000|8000|9000)(/|$|[[:space:]])'; then
      norm=$(echo "$line" | grep -oE '[a-zA-Z0-9._-]+:(8080|8443|3000|5000|8000|9000)' | head -1)
      [[ -z "$norm" ]] && norm="$line"
    fi

    # development.log só path em host “marketing” → LOW
    if echo "$line" | grep -qiE 'development\.log' \
      && ! echo "$line" | grep -qiE 'api\.(development|sandbox)|odoo\.'; then
      echo "$line" >> "${work}/LOW.txt"
      continue
    fi

    printf '%s\t%s\n' "$norm" "$line"
  done < "$high" \
    | awk -F'\t' '!seen[$1]++ {print $2}' > "$tmp"

  sort -u "$tmp" -o "$high"
  rm -f "$tmp"
  sort -u -o "${work}/LOW.txt" "${work}/LOW.txt" 2>/dev/null || true
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f polish_high 2>/dev/null || true
fi
