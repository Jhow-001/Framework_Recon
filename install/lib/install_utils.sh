#!/usr/bin/env bash

set -euo pipefail
#!/usr/bin/env bash

set -euo pipefail

#
# Descobre automaticamente a raiz do Framework
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "${SCRIPT_DIR}/../..")"

TOOLS_DIR="${ROOT_DIR}/tools"

BIN_DIR="${TOOLS_DIR}/bin"
GO_DIR="${TOOLS_DIR}/go"
PYTHON_DIR="${TOOLS_DIR}/python"

mkdir -p "$BIN_DIR"
mkdir -p "$GO_DIR"
mkdir -p "$PYTHON_DIR"
