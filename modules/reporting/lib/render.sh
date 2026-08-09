#!/bin/bash
# render.sh — summary.md, alerts.txt, findings.json (sempre)

render_report() {
  local domain="$1"
  local work="$2"
  local outdir="$3"

  mkdir -p "$outdir"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local crit high med low info
  crit=$(wc -l < "${work}/CRITICAL.txt" 2>/dev/null | tr -d ' '); crit=${crit:-0}
  high=$(wc -l < "${work}/HIGH.txt" 2>/dev/null | tr -d ' '); high=${high:-0}
  med=$(wc -l < "${work}/MEDIUM.txt" 2>/dev/null | tr -d ' '); med=${med:-0}
  low=$(wc -l < "${work}/LOW.txt" 2>/dev/null | tr -d ' '); low=${low:-0}
  info=$(wc -l < "${work}/INFO.txt" 2>/dev/null | tr -d ' '); info=${info:-0}

  # --- alerts.txt ---
  {
    echo "# ALERTS — ${domain} — ${ts}"
    echo "# Only CRITICAL + HIGH (conservative classification)"
    echo ""
    echo "## CRITICAL (${crit})"
    if [[ -s "${work}/CRITICAL.txt" ]]; then
      sort -u "${work}/CRITICAL.txt" | sed 's/^/[CRITICAL] /'
    else
      echo "(none)"
    fi
    echo ""
    echo "## HIGH (${high})"
    if [[ -s "${work}/HIGH.txt" ]]; then
      sort -u "${work}/HIGH.txt" | sed 's/^/[HIGH] /'
    else
      echo "(none)"
    fi
  } > "${outdir}/alerts.txt"

  # --- summary.md ---
  {
    echo "# Reporting V2 — ${domain}"
    echo ""
    echo "- Generated: \`${ts}\`"
    echo "- Mode: **conservative** + validate + categories"
    echo ""
    echo "## Counts"
    echo ""
    echo "| Severity | Count |"
    echo "|----------|------:|"
    echo "| CRITICAL | ${crit} |"
    echo "| HIGH     | ${high} |"
    echo "| MEDIUM   | ${med} |"
    echo "| LOW      | ${low} |"
    echo "| INFO     | ${info} |"
    echo ""
    echo "## CRITICAL"
    echo ""
    if [[ -s "${work}/CRITICAL.txt" ]]; then
      sort -u "${work}/CRITICAL.txt" | sed 's/^/- /'
    else
      echo "_None — no confirmed critical exposures._"
    fi
    echo ""
    echo "## HIGH"
    echo ""
    if [[ -s "${work}/HIGH.txt" ]]; then
      sort -u "${work}/HIGH.txt" | sed 's/^/- /'
    else
      echo "_None._"
    fi
    echo ""
    echo "## Categories (Phase 4)"
    echo ""
    if [[ -s "${work}/_categories.tsv" ]]; then
      echo "| Category | Severity | Type | Reason | Sample |"
      echo "|----------|----------|------|--------|--------|"
      head -n 40 "${work}/_categories.tsv" | while IFS=$'\t' read -r cat sev typ reason sample; do
        sample_short=$(printf '%s' "$sample" | head -c 60 | tr '|' '/')
        printf '| %s | %s | %s | %s | `%s` |\n' "$cat" "$sev" "$typ" "$reason" "$sample_short"
      done
    else
      echo "_No category hits on validated candidates._"
    fi
    echo ""
    echo "## MEDIUM (sample, max 40)"
    echo ""
    if [[ -s "${work}/MEDIUM.txt" ]]; then
      sort -u "${work}/MEDIUM.txt" | head -40 | sed 's/^/- /'
    else
      echo "_None._"
    fi
    echo ""
    echo "## LOW / INFO"
    echo ""
    echo "See \`_validated.tsv\` / \`_categories.tsv\` in work dir for audit."
  } > "${outdir}/summary.md"

  # --- findings.json (sempre grava; nunca aborta o report) ---
  local fjson="${outdir}/findings.json"
  if [[ -s "${work}/_validated.tsv" ]] && command -v jq >/dev/null 2>&1; then
    # monta array a partir do TSV validado (mais confiável que _index)
    jq -nc \
      --arg domain "$domain" \
      --arg ts "$ts" \
      --argjson crit "$crit" \
      --argjson high "$high" \
      --argjson med "$med" \
      --argjson low "$low" \
      --argjson info "$info" \
      '{
        schema_version: 1,
        domain: $domain,
        generated_at: $ts,
        mode: "conservative",
        counts: {critical:$crit, high:$high, medium:$med, low:$low, info:$info},
        findings: []
      }' > "$fjson" 2>/dev/null || true

    # enriquece findings a partir de HIGH+CRITICAL (leve)
    local tmp_nd
    tmp_nd=$(mktemp)
    : > "$tmp_nd"
    for sevfile in CRITICAL HIGH; do
      [[ -s "${work}/${sevfile}.txt" ]] || continue
      while IFS= read -r line || [[ -n "${line:-}" ]]; do
        [[ -z "${line// }" ]] && continue
        jq -nc --arg severity "$sevfile" --arg value "$line" \
          '{severity:$severity, value:$value}' >> "$tmp_nd" 2>/dev/null || true
      done < "${work}/${sevfile}.txt"
    done
    if [[ -s "$tmp_nd" ]]; then
      jq -s \
        --arg domain "$domain" \
        --arg ts "$ts" \
        --argjson crit "$crit" \
        --argjson high "$high" \
        --argjson med "$med" \
        --argjson low "$low" \
        --argjson info "$info" \
        '{
          schema_version: 1,
          domain: $domain,
          generated_at: $ts,
          mode: "conservative",
          counts: {critical:$crit, high:$high, medium:$med, low:$low, info:$info},
          findings: .
        }' "$tmp_nd" > "$fjson" 2>/dev/null || true
    fi
    rm -f "$tmp_nd"
  fi

  # fallback mínimo se ainda não existe / vazio
  if [[ ! -s "$fjson" ]]; then
    printf '%s\n' "{
  \"schema_version\": 1,
  \"domain\": \"${domain}\",
  \"generated_at\": \"${ts}\",
  \"mode\": \"conservative\",
  \"counts\": {
    \"critical\": ${crit},
    \"high\": ${high},
    \"medium\": ${med},
    \"low\": ${low},
    \"info\": ${info}
  },
  \"findings\": []
}" > "$fjson"
  fi

  echo "${outdir}/summary.md"
  echo "${outdir}/alerts.txt"
  echo "${outdir}/findings.json"
  return 0
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f render_report 2>/dev/null || true
fi
