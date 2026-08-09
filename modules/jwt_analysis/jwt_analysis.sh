#!/bin/bash
module_info() {
    echo "name=jwt_analysis"
    echo "description=Extract and analyze JWTs / interesting base64"
    echo "version=2.0"
}
module_tools() {
    echo "jwt_extract base64_mass_decode jwt_decode jwt_attacks"
}
module_mode() {
    echo "hybrid"
}
module_tool_groups() {
    echo "jwt_extract base64_mass_decode"
    echo "jwt_decode jwt_attacks"
}
module_output_name() {
    echo "jwt_analysis.txt"
}
module_execute() { :; }
