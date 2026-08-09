#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/install_utils.sh"

echo
echo "=============================================="
echo "        Cloud Module Installer"
echo "=============================================="
echo

install_bucket_stream() {

    info "=================================================="
    info "Instalando bucket-stream"
    info "=================================================="

    local REPO="https://github.com/eth0izzle/bucket-stream.git"
    local DIR="${GO_DIR}/bucket-stream"

    clone_or_update "$REPO" "$DIR"

    cd "$DIR"

    info "Compilando..."

    go build -o bucket-stream .

    create_link \
        "${DIR}/bucket-stream" \
        "bucket-stream"

    validate_tool "bucket-stream"

    echo

}

install_cloudbrute() {

}

install_s3scanner() {

}

install_s3enum() {

}

install_gcpbucketbrute() {

}

install_cloud_enum() {

}

main() {

    install_bucket_stream

    install_cloudbrute

    install_s3scanner

    install_s3enum

    install_gcpbucketbrute

    install_cloud_enum

    echo
    ok "Cloud Module instalado com sucesso."
    echo

}

main "$@"
