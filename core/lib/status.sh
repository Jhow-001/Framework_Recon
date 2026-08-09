#!/usr/bin/env bash
# core/lib/status.sh

print_status() {
    local tool="$1"
    local status="$2"
    printf "[*] %-20s %s\n" "$tool" "$status"
}
