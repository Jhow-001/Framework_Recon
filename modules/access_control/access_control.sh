#!/bin/bash
# modules/access_control/access_control.sh

module_info() {
    echo "name=access_control"
    echo "description=IDOR/BOLA/BAC heuristics + nuclei access tags"
    echo "version=2.0"
}

module_tools() {
    echo "bac_paths bola_api idor_scanner nuclei_access"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "access_control.txt"
}

module_execute() {
    :
}
