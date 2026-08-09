#!/bin/bash
module_info() {
    echo "name=crawling"
    echo "description=URL discovery + classified artifacts"
    echo "version=2.1"
}
module_tools() {
    echo "gau katana"
}
module_mode() {
    echo "parallel"
}
module_output_name() {
    echo "crawling.txt"   # dump completo (compat)
}
module_execute() { :; }

# Após merge de gau+katana → artefatos especializados
module_finalize() {
    local merged="${1:?}"
    local tmpdir work
    tmpdir=$(mktemp -d) || return 0

    awk '{print $1}' "$merged" 2>/dev/null | sed '/^$/d' | sort -u > "$tmpdir/all.txt" || : > "$tmpdir/all.txt"
    cp "$tmpdir/all.txt" "$tmpdir/urls.txt"

    grep -Ei '\.js(\?|$)|/static/.*\.js|webpack|chunk' "$tmpdir/all.txt" \
      | head -n "${CRAWL_MAX_JS:-500}" > "$tmpdir/js.txt" 2>/dev/null || : > "$tmpdir/js.txt"

    grep -Ei '/api[/]|/v[0-9]+/|/graphql|swagger|openapi|/rest/' "$tmpdir/all.txt" \
      | head -n "${CRAWL_MAX_API:-400}" > "$tmpdir/api_endpoints.txt" 2>/dev/null || : > "$tmpdir/api_endpoints.txt"

    grep -E '\?.+=|&.+=|=.' "$tmpdir/all.txt" \
      | head -n "${CRAWL_MAX_PARAMS:-400}" > "$tmpdir/parameters.txt" 2>/dev/null || : > "$tmpdir/parameters.txt"

    grep -Ei 'token|jwt|auth|session|bearer|access_token' "$tmpdir/all.txt" \
      | head -n "${CRAWL_MAX_JWT:-150}" > "$tmpdir/jwt_candidates.txt" 2>/dev/null || : > "$tmpdir/jwt_candidates.txt"

    grep -Ei 'form|login|signin|register|password|submit' "$tmpdir/all.txt" \
      | head -n "${CRAWL_MAX_FORMS:-150}" > "$tmpdir/forms.txt" 2>/dev/null || : > "$tmpdir/forms.txt"

    cat "$tmpdir/parameters.txt" "$tmpdir/api_endpoints.txt" 2>/dev/null \
      | sort -u | head -n "${CRAWL_MAX_VULN:-400}" > "$tmpdir/vuln_targets.txt" || : > "$tmpdir/vuln_targets.txt"

    storage_write_artifact "crawling" "urls.txt"           "$tmpdir/urls.txt"           >/dev/null
    storage_write_artifact "crawling" "js.txt"             "$tmpdir/js.txt"             >/dev/null
    storage_write_artifact "crawling" "api_endpoints.txt"  "$tmpdir/api_endpoints.txt"  >/dev/null
    storage_write_artifact "crawling" "parameters.txt"      "$tmpdir/parameters.txt"      >/dev/null
    storage_write_artifact "crawling" "jwt_candidates.txt" "$tmpdir/jwt_candidates.txt" >/dev/null
    storage_write_artifact "crawling" "forms.txt"          "$tmpdir/forms.txt"          >/dev/null
    storage_write_artifact "crawling" "crawling.txt"       "$tmpdir/all.txt"            >/dev/null
    storage_write_artifact "crawling" "vuln_targets.txt"   "$tmpdir/vuln_targets.txt"   >/dev/null

    log_info "crawling artifacts: js=$(wc -l <"$tmpdir/js.txt" | tr -d ' ') api=$(wc -l <"$tmpdir/api_endpoints.txt" | tr -d ' ') params=$(wc -l <"$tmpdir/parameters.txt" | tr -d ' ')"

    rm -rf "$tmpdir"
    return 0
}
