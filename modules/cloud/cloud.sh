#!/bin/bash
# modules/cloud/cloud.sh — contrato V2

module_info() {
    echo "name=cloud"
    echo "description=Cloud storage enumeration (S3 / cloudbrute)"
    echo "version=2.0"
}

module_tools() {
    # buckets = mutações; s3scanner/cloudbrute = o que importa no merge
    echo "buckets s3scanner cloudbrute"
}

module_mode() {
    echo "parallel"
}

module_output_name() {
    echo "cloud.txt"
}

module_execute() {
    :
}
