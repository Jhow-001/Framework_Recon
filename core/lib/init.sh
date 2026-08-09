#!/usr/bin/env bash

[[ -n "${_INIT_LOADED:-}" ]] && return 0
_INIT_LOADED=1

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${LIB_DIR}/../bootstrap.sh"
