#!/bin/bash
# modules/osint/osint.sh — contrato V2

module_info() {
    echo "name=osint"
    echo "description=OSINT hosts, repos, exposed .git, secrets"
    echo "version=2.0"
}

module_tools() {
    # crt/whois/censys = contexto/hosts
    # github = repos
    # gitdumper = .git exposto
    # gitleaks = secrets (.env, keys)
    echo "crt whois censys github gitdumper gitleaks trufflehog shodan"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "osint.txt"
}

module_execute() {
    :
}
