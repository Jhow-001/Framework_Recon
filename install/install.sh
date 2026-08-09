#!/usr/bin/env bash
# install/install.sh
# Instalação completa e idempotente do Framework Recon
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo -e "[\e[34minstall\e[0m] $*"; }
ok()   { echo -e "[\e[32mok\e[0m] $*"; }
warn() { echo -e "[\e[33mwarn\e[0m] $*"; }
die()  { echo -e "[\e[31merro\e[0m] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Dependências de sistema
# ---------------------------------------------------------------------------
install_system_deps() {
    log "Atualizando repositórios e instalando dependências de sistema..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y \
        curl wget git jq unzip zip \
        python3 python3-pip python3-venv python3-dev \
        golang-go build-essential libpcap-dev \
        nmap masscan \
        whois dnsutils \
        chromium 2>/dev/null || apt-get install -y chromium-browser 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 2. Configuração do ambiente Go
# ---------------------------------------------------------------------------
setup_go_env() {
    # Quando executado com sudo, manter o GOPATH do usuário real
    local real_user="${SUDO_USER:-$USER}"
    local real_home
    real_home=$(getent passwd "$real_user" | cut -d: -f6)

    export GOPATH="${real_home}/go"
    export GOBIN="${GOPATH}/bin"
    export PATH="${PATH}:${GOBIN}:/usr/local/go/bin"

    mkdir -p "${GOPATH}/bin"
    log "GOPATH configurado em: ${GOPATH}"
}

# ---------------------------------------------------------------------------
# 3. Ferramentas Go
# ---------------------------------------------------------------------------
install_go_tools() {
    log "Instalando ferramentas Go (pode demorar)..."

    local tools=(
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/katana/cmd/katana@latest"
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
    "github.com/ffuf/ffuf/v2@latest"
    "github.com/tomnomnom/assetfinder@latest"
    "github.com/lc/gau/v2/cmd/gau@latest"
    "github.com/tomnomnom/waybackurls@latest"
    "github.com/hakluke/hakrawler@latest"
    "github.com/jaeles-project/gospider@latest"
    "github.com/d3mondev/puredns/v2@latest"
    "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
    "github.com/sensepost/gowitness@latest"
    "github.com/hahwul/dalfox/v2@latest"
    "github.com/BishopFox/jsluice/cmd/jsluice@latest"
    "github.com/0xsha/cloudbrute@latest"
    "github.com/owasp-amass/amass/v4/...@master"
    "github.com/sa7mon/s3scanner@latest"
)

    for tool in "${tools[@]}"; do
        log "→ go install $tool"
        go install -v "$tool" || warn "Falha ao instalar $tool (continuando...)"
    done

    # Garante que os binários fiquem acessíveis no PATH do sistema
    if [[ -d "${GOBIN}" ]]; then
        ln -sf "${GOBIN}"/* /usr/local/bin/ 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# 4. Ferramentas Python / pipx
# ---------------------------------------------------------------------------
install_python_tools() {
    log "Instalando ferramentas Python (via pipx / apt)..."

    # Garante pipx
    if ! command -v pipx &>/dev/null; then
        apt-get install -y pipx 2>/dev/null || pip3 install --user pipx 2>/dev/null || true
        pipx ensurepath 2>/dev/null || true
        export PATH="${PATH}:${HOME}/.local/bin"
    fi

    # Preferir pacotes do sistema quando existirem
    apt-get install -y \
        python3-arjun \
        python3-wafw00f \
        2>/dev/null || true

    # Ferramentas prioritárias via pipx (isoladas)
    local py_tools=(
        "arjun"
        "wafw00f"
        "dirsearch"
        "detect-secrets"
        "waymore"
    )

    for tool in "${py_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            ok "$tool já presente"
            continue
        fi
        log "→ pipx install $tool"
        pipx install "$tool" 2>/dev/null || warn "Não foi possível instalar $tool via pipx"
    done
}

# ---------------------------------------------------------------------------
# 5. Ferramentas adicionais via apt / outros
# ---------------------------------------------------------------------------
install_extra_tools() {
    log "Instalando ferramentas extras via apt..."

    apt-get install -y \
        sqlmap \
        whatweb \
        feroxbuster \
        gobuster \
        trufflehog \
        gitleaks \
        2>/dev/null || true

    # findomain (binário pré-compilado se não estiver presente)
    if ! command -v findomain &>/dev/null; then
        log "Instalando findomain..."
        curl -sLO https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip
        unzip -o findomain-linux.zip
        chmod +x findomain
        mv findomain /usr/local/bin/
        rm -f findomain-linux.zip
    fi
}

# ---------------------------------------------------------------------------
# 6. Estrutura de diretórios e wordlists
# ---------------------------------------------------------------------------
prepare_runtime() {
    log "Criando estrutura de diretórios de runtime..."
    mkdir -p \
        cache/{downloads,temporary,workspace} \
        logs \
        results \
        database \
        wordlists/{dns,paths,exposure,api,cloud}

    # Garante permissões corretas para o usuário real
    local real_user="${SUDO_USER:-$USER}"
    chown -R "${real_user}:${real_user}" cache logs results database 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 7. Validação final
# ---------------------------------------------------------------------------
validate_installation() {
    log "Validando instalação..."

    if [[ -x "${ROOT_DIR}/install/check_tools.sh" ]]; then
        bash "${ROOT_DIR}/install/check_tools.sh"
    else
        local critical=(httpx dnsx naabu katana nuclei ffuf subfinder jq nmap)
        local missing=0
        for tool in "${critical[@]}"; do
            if command -v "$tool" &>/dev/null; then
                ok "$tool"
            else
                warn "Ausente: $tool"
                ((missing++)) || true
            fi
        done
        [[ $missing -eq 0 ]] && ok "Ferramentas críticas presentes" || \
            warn "$missing ferramenta(s) crítica(s) ausente(s)"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    [[ $EUID -eq 0 ]] || die "Execute com sudo: sudo ./install/install.sh"

    log "Iniciando instalação do Framework Recon"
    log "Diretório raiz: ${ROOT_DIR}"

    install_system_deps
    setup_go_env
    install_go_tools
    install_python_tools
    install_extra_tools
    prepare_runtime
    validate_installation

    echo
    ok "Instalação finalizada."
    log "Próximo passo: ./run.sh <alvo.com>"
}

main "$@"
