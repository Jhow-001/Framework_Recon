#!/usr/bin/env bash
set -euo pipefail

export PATH="$PATH:$HOME/go/bin:$(go env GOPATH 2>/dev/null)/bin:$HOME/.local/bin"
TOOLS_DIR="${HOME}/recon-tools"
mkdir -p "$TOOLS_DIR" "$HOME/go/bin"

echo "[*] Instalando opcionais do Framework Recon..."

# --- rustscan ---
sudo apt install -y rustscan 2>/dev/null || cargo install rustscan 2>/dev/null || true

# --- waymore / dirsearch / detect-secrets (PATH) ---
pipx install waymore 2>/dev/null || pipx upgrade waymore 2>/dev/null || true
pipx install dirsearch 2>/dev/null || true
pipx install detect-secrets 2>/dev/null || true

# --- webanalyze ---
go install github.com/rverton/webanalyze/cmd/webanalyze@latest 2>/dev/null || true

# --- kiterunner ---
go install github.com/assetnote/kiterunner/cmd/kr@latest 2>/dev/null || true

# --- githound ---
go install github.com/tillson/git-hound@latest 2>/dev/null || true

# --- s3scanner ---
go install github.com/sa7mon/s3scanner@latest 2>/dev/null || true

# --- s3enum ---
go install github.com/koenrh/s3enum@latest 2>/dev/null || true

# --- cloudbrute ---
go install github.com/0xsha/cloudbrute@latest 2>/dev/null || true

# --- aquatone (binário release; repo arquivado) ---
if ! command -v aquatone >/dev/null 2>&1; then
    tmp=$(mktemp -d)
    (cd "$tmp" && \
      curl -sL "https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip" -o aq.zip && \
      unzip -o aq.zip && \
      sudo mv aquatone /usr/local/bin/ && \
      sudo chmod +x /usr/local/bin/aquatone) 2>/dev/null || true
    rm -rf "$tmp"
fi

# --- xnLinkFinder ---
if [[ ! -d "$TOOLS_DIR/xnLinkFinder" ]]; then
    git clone --depth 1 https://github.com/xnl-h4ck3r/xnLinkFinder.git "$TOOLS_DIR/xnLinkFinder"
    pipx install "$TOOLS_DIR/xnLinkFinder" 2>/dev/null || \
      python3 -m pip install --user -r "$TOOLS_DIR/xnLinkFinder/requirements.txt" 2>/dev/null || true
fi
# wrapper
cat > "$HOME/go/bin/xnLinkFinder" << 'EOF'
#!/usr/bin/env bash
if command -v xnLinkFinder >/dev/null 2>&1 && [[ "$(command -v xnLinkFinder)" != "$0" ]]; then
  command xnLinkFinder "$@"
else
  python3 "$HOME/recon-tools/xnLinkFinder/xnLinkFinder.py" "$@"
fi
EOF
chmod +x "$HOME/go/bin/xnLinkFinder"

# --- GitDorker ---
if [[ ! -d "$TOOLS_DIR/GitDorker" ]]; then
    git clone --depth 1 https://github.com/obheda12/GitDorker.git "$TOOLS_DIR/GitDorker"
    python3 -m pip install --user -r "$TOOLS_DIR/GitDorker/requirements.txt" 2>/dev/null || true
fi
cat > "$HOME/go/bin/GitDorker" << 'EOF'
#!/usr/bin/env bash
python3 "$HOME/recon-tools/GitDorker/GitDorker.py" "$@"
EOF
chmod +x "$HOME/go/bin/GitDorker"

# --- gcpbucketbrute ---
if [[ ! -d "$TOOLS_DIR/GCPBucketBrute" ]]; then
    git clone --depth 1 https://github.com/RhinoSecurityLabs/GCPBucketBrute.git "$TOOLS_DIR/GCPBucketBrute"
    python3 -m pip install --user -r "$TOOLS_DIR/GCPBucketBrute/requirements.txt" 2>/dev/null || true
fi
cat > "$HOME/go/bin/gcpbucketbrute" << 'EOF'
#!/usr/bin/env bash
python3 "$HOME/recon-tools/GCPBucketBrute/gcpbucketbrute.py" "$@"
EOF
chmod +x "$HOME/go/bin/gcpbucketbrute"

# --- crobat (pode falhar: repo antigo) ---
go install github.com/cgboes/crobat/cmd/crobat@latest 2>/dev/null || \
  echo "[!] crobat indisponível (repo antigo) — ignore"

# --- wappalyzer CLI (via npm se existir) ---
if command -v npm >/dev/null 2>&1; then
    sudo npm install -g wappalyzer 2>/dev/null || true
else
    echo "[*] wappalyzer: opcional via npm install -g wappalyzer"
fi

# webprobe → alias para httprobe (o framework já tem httprobe)
cat > "$HOME/go/bin/webprobe" << 'EOF'
#!/usr/bin/env bash
# Compat: webprobe → httprobe
exec httprobe "$@"
EOF
chmod +x "$HOME/go/bin/webprobe"

echo
echo "[+] Opcionais processados."
echo "[*] Rode: export PATH=\"\$PATH:\$HOME/go/bin:\$HOME/.local/bin\""
echo "[*] Depois: ./install/check_tools.sh"
