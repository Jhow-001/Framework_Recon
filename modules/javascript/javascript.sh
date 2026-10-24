#!/bin/bash
# modules/javascript/javascript.sh — V2.1 hybrid JS recon
module_info() {
    echo "name=javascript"
    echo "description=Collect JS + extract endpoints/secrets"
    echo "version=2.1"
}
module_tools() {
    echo "getjs subjs gau_js httpx_js jsluice xnlinkfinder keywords_grep"
}
module_mode() {
    echo "hybrid"
}
module_tool_groups() {
    echo "getjs subjs gau_js"
    echo "httpx_js"
    echo "jsluice xnlinkfinder keywords_grep"
}
module_output_name() {
    echo "javascript.txt"
}
module_execute() { :; }
module_finalize() {
    local merged="${1:?}"
    local dir tmp
    dir="$(storage_module_dir "javascript" 2>/dev/null || true)"
    tmp=$(mktemp -d) || return 0
    awk '{print $1}' "$merged" 2>/dev/null | sed '/^$/d' | sort -u > "$tmp/all.txt" || : > "$tmp/all.txt"
    grep -E '^/' "$tmp/all.txt" > "$tmp/endpoints.txt" || : > "$tmp/endpoints.txt"
    grep -E '^https?://' "$tmp/all.txt" | grep -viE '\.js(\?|$)' >> "$tmp/endpoints.txt" || true
    grep -E '^https?://' "$tmp/all.txt" | grep -iE '\.js(\?|$)' > "$tmp/live_js.txt" || : > "$tmp/live_js.txt"
    sort -u -o "$tmp/endpoints.txt" "$tmp/endpoints.txt" || true
    storage_write_artifact "javascript" "endpoints.txt" "$tmp/endpoints.txt" >/dev/null 2>&1 || {
        [[ -n "$dir" ]] && cp -f "$tmp/endpoints.txt" "$dir/endpoints.txt" && cp -f "$tmp/live_js.txt" "$dir/live_js.txt"
    }
    storage_write_artifact "javascript" "live_js.txt" "$tmp/live_js.txt" >/dev/null 2>&1 || true
    if declare -F storage_write_artifact >/dev/null 2>&1 && [[ -s "$tmp/endpoints.txt" ]]; then
        local extra
        extra=$(mktemp)
        cat "$tmp/endpoints.txt" > "$extra"
        [[ -s "${ROOT_DIR:-}/results/${TARGET_DOMAIN}/crawling/api_endpoints.txt" ]] && \
            cat "${ROOT_DIR}/results/${TARGET_DOMAIN}/crawling/api_endpoints.txt" >> "$extra" || true
        sort -u -o "$extra" "$extra"
        storage_write_artifact "crawling" "api_endpoints.txt" "$extra" >/dev/null 2>&1 || true
        rm -f "$extra"
    fi
    log_info "javascript artifacts: endpoints=$(wc -l <"$tmp/endpoints.txt" | tr -d ' ') live_js=$(wc -l <"$tmp/live_js.txt" | tr -d ' ')"
    rm -rf "$tmp"
    return 0
}
