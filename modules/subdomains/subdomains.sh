#!/bin/bash
# modules/subdomains/subdomains.sh

module_info() {
    echo "name=subdomains"
    echo "description=Enumeração de subdomínios"
    echo "version=2.0"
}

module_tools() {
    echo "assetfinder chaos findomain crobat "
}

module_mode() {
    echo "parallel"
}

module_execute() {
    :
}

module_output_name() {
    echo "subdomains.txt"
}
