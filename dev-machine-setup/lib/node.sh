#!/usr/bin/env bash
# =============================================================================
# lib/node.sh - Instalação do NVM + Node LTS
# =============================================================================

install_node() {
    log_info "Configurando NVM + Node.js LTS..."

    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"

    # Instala NVM
    if [[ ! -d "$nvm_dir" ]]; then
        run_silent "Instalando NVM (gerenciador de versões Node)" \
            bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash'
    else
        log_warning "NVM já instalado em: $nvm_dir"
    fi

    # Snippets para .zshrc e .bashrc
    local nvm_snippet='
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [[ -f "$rc" ]] && ! grep -q 'NVM_DIR' "$rc"; then
            echo "$nvm_snippet" >> "$rc"
        fi
    done

    # Carrega NVM na sessão atual (sem set -u para evitar erro do NVM)
    export NVM_DIR="$nvm_dir"
    set +u
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    set -u

    # Instala Node LTS
    if command -v nvm &>/dev/null; then
        local installed
        set +u
        installed="$(nvm ls lts/* 2>/dev/null | grep -v 'N/A' | head -1 || true)"
        set -u

        if [[ -z "$installed" ]]; then
            run_silent "Instalando Node.js LTS" \
                bash -c "export NVM_DIR=\"$nvm_dir\" && source \"$NVM_DIR/nvm.sh\" && nvm install --lts && nvm alias default lts/*"
        else
            log_warning "Node.js já instalado: $(node --version 2>/dev/null || echo 'reabra o terminal')"
        fi
    else
        log_warning "NVM não disponível na sessão. Execute 'source ~/.zshrc' e depois: nvm install --lts"
    fi

    log_success "NVM + Node.js LTS configurados."
}
