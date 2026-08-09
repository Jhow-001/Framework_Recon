#!/bin/bash
# Lê results/$DOMAIN e produz findings classificados

parse_all_modules() {
  local domain="$1"
  local base="${ROOT_DIR}/results/${domain}"
  local out_dir="${base}/report"
  mkdir -p "$out_dir"

  local critical_f="${out_dir}/.critical.tmp"
  local high_f="${out_dir}/.high.tmp"
  local medium_f="${out_dir}/.medium.tmp"
  local low_f="${out_dir}/.low.tmp"
  local surface_f="${out_dir}/.surface.tmp"

  : > "$critical_f" ; : > "$high_f" ; : > "$medium_f" ; : > "$low_f" ; : > "$surface_f"

  # Lista de módulos prioritários (ordem de leitura)
  local modules=(
    vulnerability exposure_assessment access_control jwt_analysis api
    cloud subdomains dns_resolution http_probe ports_scan waf_detection
    crawling javascript fuzzing osint screenshots
  )

  for mod in "${modules[@]}"; do
    local mod_dir="${base}/${mod}"
    [[ -d "$mod_dir" ]] || continue

    # module.txt principal
    local mod_txt="${mod_dir}/module.txt"
    [[ -f "$mod_txt" ]] || mod_txt="${mod_dir}/${mod}.txt"

    if [[ -s "$mod_txt" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        local prio
        prio=$(classify_line "$line" "$mod")
        case "$prio" in
          critical) echo "[$mod] $line" >> "$critical_f" ;;
          high)     echo "[$mod] $line" >> "$high_f" ;;
          medium)   echo "[$mod] $line" >> "$medium_f" ;;
          low)      echo "[$mod] $line" >> "$low_f" ;;
        esac
      done < "$mod_txt"
    fi

    # Superfície de ataque (sempre coletar hosts/urls limpos)
    case "$mod" in
      subdomains|dns_resolution)
        [[ -s "$mod_txt" ]] && cat "$mod_txt" >> "$surface_f"
        ;;
      http_probe)
        [[ -s "$mod_txt" ]] && awk '{print $1}' "$mod_txt" >> "$surface_f"
        ;;
    esac
  done

  # Dedup
  for f in "$critical_f" "$high_f" "$medium_f" "$low_f" "$surface_f"; do
    [[ -s "$f" ]] && sort -u -o "$f" "$f"
  done

  # Exporta caminhos para o render
  echo "$critical_f|$high_f|$medium_f|$low_f|$surface_f"
}

export -f parse_all_modules
