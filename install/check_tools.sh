#!/usr/bin/env bash
# install/check_tools.sh
# Verifica quais ferramentas do framework estão instaladas

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/go/bin:$(go env GOPATH 2>/dev/null)/bin:${PATH}"

echo "=============================================="
echo "  Framework Recon - Inventário de Ferramentas"
echo "=============================================="
echo

OK=0
MISSING=0
OPTIONAL=0

check() {
    local name="$1"
    local bin="$2"
    local required="${3:-yes}"

    if command -v "$bin" >/dev/null 2>&1; then
        local path
        path=$(command -v "$bin")
        printf "[OK]       %-22s → %s\n" "$name" "$path"
        OK=$((OK + 1))
    else
        if [[ "$required" == "yes" ]]; then
            printf "[FALTA]    %-22s (obrigatória)\n" "$name"
            MISSING=$((MISSING + 1))
        else
            printf "[OPCIONAL] %-22s (não instalada)\n" "$name"
            OPTIONAL=$((OPTIONAL + 1))
        fi
    fi
}

echo "--- Subdomains ---"
check "subfinder"         "subfinder"
check "assetfinder"       "assetfinder"
check "findomain"         "findomain"
check "chaos"             "chaos"
check "github-subdomains" "github-subdomains" "no"
check "crobat"            "crobat" "no"

echo
echo "--- DNS ---"
check "dnsx"              "dnsx"
check "puredns"           "puredns"
check "shuffledns"        "shuffledns"
check "massdns"           "massdns" "no"

echo
echo "--- HTTP / Probe ---"
check "httpx"             "httpx"
check "httprobe"          "httprobe" "no"
check "webprobe"          "webprobe" "no"

echo
echo "--- Ports ---"
check "naabu"             "naabu"
check "nmap"              "nmap"
check "masscan"           "masscan"
check "rustscan"          "rustscan" "no"

echo
echo "--- Crawling ---"
check "katana"            "katana"
check "gau"               "gau"
check "waybackurls"       "waybackurls"
check "waymore"           "waymore" "no"
check "gospider"          "gospider"
check "hakrawler"         "hakrawler"

echo
echo "--- Technology / WAF ---"
check "whatweb"           "whatweb"
check "wappalyzer"        "wappalyzer" "no"
check "webanalyze"        "webanalyze" "no"
check "wafw00f"           "wafw00f"

echo
echo "--- Fuzzing ---"
check "ffuf"              "ffuf"
check "feroxbuster"       "feroxbuster"
check "gobuster"          "gobuster"
check "dirsearch"         "dirsearch" "no"

echo
echo "--- API ---"
check "arjun"             "arjun"
check "kiterunner/kr"     "kr" "no"
check "kiterunner"        "kiterunner" "no"

echo
echo "--- JS ---"
check "linkfinder"        "linkfinder" "no"
check "xnLinkFinder"      "xnLinkFinder" "no"
check "jsluice"           "jsluice" "no"
check "urlfinder"         "urlfinder" "no"
check "getJS"             "getJS" "no"
check "subjs"             "subjs" "no"

echo
echo "--- Cloud ---"
check "cloudbrute"        "cloudbrute" "no"
check "cloud_enum"        "cloud_enum" "no"
check "s3scanner"         "s3scanner" "no"
check "s3enum"            "s3enum" "no"
check "gcpbucketbrute"    "gcpbucketbrute" "no"

echo
echo "--- OSINT / Secrets ---"
check "shodan"            "shodan" "no"
check "censys"            "censys" "no"
check "whois"             "whois"
check "gitleaks"          "gitleaks" "no"
check "trufflehog"        "trufflehog" "no"
check "githound"          "githound" "no"
check "git-dumper"        "git-dumper" "no"
check "GitDorker"         "GitDorker" "no"
check "detect-secrets"    "detect-secrets" "no"
check "rg (ripgrep)"      "rg"

echo
echo "--- Screenshots ---"
check "gowitness"         "gowitness" "no"
check "aquatone"          "aquatone" "no"
check "eyewitness"        "eyewitness" "no"

echo
echo "--- Vuln / Exposure ---"
check "nuclei"            "nuclei"
check "dalfox"            "dalfox" "no"
check "sqlmap"            "sqlmap"

echo
echo "--- JWT ---"
check "jwt_tool"          "jwt_tool" "no"
check "jwt-tool"          "jwt-tool" "no"

echo
echo "--- Base ---"
check "curl"              "curl"
check "git"               "git"
check "jq"                "jq" "no"
check "go"                "go" "no"

echo
echo "=============================================="
echo "  Instaladas : $OK"
echo "  Faltando   : $MISSING  (prioritárias)"
echo "  Opcionais  : $OPTIONAL"
echo "=============================================="
