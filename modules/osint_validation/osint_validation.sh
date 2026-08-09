#!/bin/bash
# Valida APENAS o que o módulo osint já descobriu (input = osint.txt)

module_info() {
    echo "name=osint_validation"
    echo "description=Validate OSINT findings only — no new discovery"
    echo "version=2.0"
}

module_tools() {
    echo "validate_github validate_gitdumper validate_gitleaks validate_trufflehog validate_generic validate_aws validate_slack detect_secrets"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "validated_secrets.txt"
}

module_execute() {
    :
}
