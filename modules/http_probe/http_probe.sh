#!/bin/bash
# modules/http_probe/http_probe.sh — contrato V2

module_info() {
    echo "name=http_probe"
    echo "description=HTTP probe de hosts resolvidos"
    echo "version=2.0"
}

module_tools() {
    echo "httpx"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "http.txt"
}

module_execute() {
    :
}
