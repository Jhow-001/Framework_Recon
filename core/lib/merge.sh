#!/usr/bin/env bash
# core/lib/merge.sh

merge_unique() {
    local output="$1"
    shift
    cat "$@" 2>/dev/null | sort -u > "$output"
}
