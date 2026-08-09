#!/bin/bash
# modules/javascript/javascript.sh — V2
# Input: URLs (crawling.txt / http.txt)

module_info() {
    echo "name=javascript"
    echo "description=Extract endpoints from JS / pages"
    echo "version=2.0"
}

module_tools() {
    echo "jsluice xnlinkfinder"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "javascript.txt"
}

module_execute() {
    :
}
