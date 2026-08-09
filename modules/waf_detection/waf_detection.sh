#!/bin/bash
# modules/waf_detection/waf_detection.sh — contrato V2

module_info() {
    echo "name=waf_detection"
    echo "description=WAF detection on live HTTP URLs"
    echo "version=2.0"
}

module_tools() {
    echo "wafw00f"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "waf.txt"
}

module_execute() {
    :
}
