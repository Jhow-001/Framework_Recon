#!/bin/bash
# Contrato V2 — $1 = saída do naabu (host ou host:port), $2 stdout, $3 stderr

if [[ "${1:-}" == "--info" ]]; then
    echo "name=nmap"
    echo "version=1.0"
    echo "description=Service/version on ports found by naabu"
    exit 0
fi

INPUT_FILE="$1"
STDOUT_FILE="$2"
STDERR_FILE="$3"

if ! command -v nmap >/dev/null 2>&1; then
    echo "binary not found: nmap" >> "$STDERR_FILE"
    exit 127
fi

if [[ ! -s "$INPUT_FILE" ]]; then
    exit 0
fi

TARGETS=$(mktemp)
PORTS_FILE=$(mktemp)
: > "$TARGETS"
: > "$PORTS_FILE"

awk '
{
  gsub(/\r/,"");
  if ($0 ~ /^#/ || $0 == "") next;
  if ($0 ~ /:/) {
    split($0, a, ":");
    host=a[1]; port=a[2];
    gsub(/[^0-9]/, "", port);
    if (host != "" && port != "") {
      print host;
      print port >> "'"$PORTS_FILE"'";
    }
  } else {
    print $1;
  }
}' "$INPUT_FILE" | sort -u > "$TARGETS"

sort -u -o "$PORTS_FILE" "$PORTS_FILE" 2>/dev/null || true

if [[ ! -s "$TARGETS" ]]; then
    rm -f "$TARGETS" "$PORTS_FILE"
    exit 0
fi

if [[ -s "$PORTS_FILE" ]]; then
    PORT_LIST=$(paste -sd, "$PORTS_FILE")
else
    PORT_LIST="21,22,25,53,80,110,143,443,445,587,993,995,3306,3389,8080,8443"
fi

nmap -iL "$TARGETS" \
     -p "$PORT_LIST" \
     -sCV \
     -T4 -Pn \
     --max-retries 1 \
     --host-timeout 90s \
     -oN "$STDOUT_FILE" \
     >>"$STDERR_FILE" 2>&1 || true

rm -f "$TARGETS" "$PORTS_FILE"
exit 0
