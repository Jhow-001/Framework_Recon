#!/bin/bash
module_info() {
    echo "name=api"
    echo "description=API endpoints and parameter discovery"
    echo "version=2.0"
}
module_tools() {
    echo "arjun ffuf"
}
module_mode() {
    echo "parallel"
}
module_output_name() {
    echo "api.txt"
}
module_execute() { :; }
