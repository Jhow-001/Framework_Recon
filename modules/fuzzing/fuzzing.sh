#!/bin/bash
module_info() {
    echo "name=fuzzing"
    echo "description=Directory fuzzing on live URLs"
    echo "version=2.0"
}
module_tools() {
    echo "ffuf"
}
module_mode() {
    echo "serial"
}
module_output_name() {
    echo "fuzzing.txt"
}
module_execute() { :; }
