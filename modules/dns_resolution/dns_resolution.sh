#!/bin/bash
# modules/dns_resolution/dns_resolution.sh — contrato V2

module_info() {
    echo "name=dns_resolution"
    echo "description=Resolução DNS de hosts descobertos"
    echo "version=2.0"
}

module_tools() {
    echo "dnsx puredns"
}

module_mode() {
    echo "parallel"
}

# Pipeline.conf output: dns.txt
module_output_name() {
    echo "dns.txt"
}

module_execute() {
    :
}
