#!/bin/bash
# modules/ports_scan/ports_scan.sh — contrato V2 (hybrid)

module_info() {
    echo "name=ports_scan"
    echo "description=Port scan: naabu discovery then nmap service"
    echo "version=2.0"
}

module_tools() {
    echo "naabu nmap"
}

module_mode() {
    echo "hybrid"
}

# Grupo 1 → naabu; grupo 2 → nmap (input = saída do naabu)
module_tool_groups() {
    echo "naabu"
    echo "nmap"
}

module_output_name() {
    echo "ports.txt"
}

module_execute() {
    :
}
