#!/bin/bash
# Input: http.txt (URLs). Só valida exposição — não é crawler geral.

module_info() {
    echo "name=exposure_assessment"
    echo "description=Sensitive files, admin panels, nuclei exposure tags"
    echo "version=2.0"
}

module_tools() {
    echo "nuclei_exposure ffuf_panels ffuf_sensitive"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "exposure.txt"
}

module_execute() {
    :
}
