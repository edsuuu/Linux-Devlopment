#!/usr/bin/env bash
# =============================================================================
# lib/node.sh - Instalação do NVM + Node LTS
# =============================================================================

install_node() {
    log_info "Verificando/instalando NVM + Node.js LTS..."

    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"

    # Instala NVM sem fixar versão (sempre pega a mais recente via site oficial)
    if [[ ! -d "$nvm_dir" ]]; then
        log_info "Instalando NVM via script oficial..."
        # O instalador oficial sempre baixa a versão mais recente
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
        log_success "NVM instalado."
    else
        log_warning "NVM já está instalado em: $nvm_dir"
    fi

    # Carrega NVM na sessão atual
    export NVM_DIR="$nvm_dir"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    # Garante que NVM esteja no .zshrc
    local nvm_snippet='
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    if ! grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null; then
        echo "$nvm_snippet" >> "$HOME/.zshrc"
    fi

    if ! grep -q 'NVM_DIR' "$HOME/.bashrc" 2>/dev/null; then
        echo "$nvm_snippet" >> "$HOME/.bashrc"
    fi

    # Instala Node.js LTS
    if command -v nvm &>/dev/null; then
        if ! nvm ls lts/* &>/dev/null | grep -q "lts"; then
            log_info "Instalando Node.js LTS..."
            nvm install --lts
            nvm use --lts
            nvm alias default lts/*
            log_success "Node.js LTS instalado: $(node --version)"
        else
            log_warning "Node.js LTS já está instalado: $(node --version 2>/dev/null || echo 'recarregue o terminal')"
        fi
    else
        log_warning "NVM não disponível na sessão atual. Execute 'source ~/.zshrc' e instale o Node manualmente com: nvm install --lts"
    fi
}
