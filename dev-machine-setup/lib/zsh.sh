#!/usr/bin/env bash
# =============================================================================
# lib/zsh.sh - Instalação do ZSH + Oh My Zsh + Spaceship + plugins
# Tema: duellj | Plugins: git, autosuggestions, syntax-highlighting
# =============================================================================

install_zsh() {
    log_info "Configurando ZSH + Oh My Zsh..."

    # Instala ZSH
    if ! command -v zsh &>/dev/null; then
        run_silent "Instalando ZSH" \
            sudo apt-get install -y zsh
    else
        log_warning "ZSH já instalado: $(zsh --version)"
    fi

    # Shell padrão
    local zsh_path
    zsh_path="$(command -v zsh)"
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$current_shell" != "$zsh_path" ]]; then
        run_silent "Definindo ZSH como shell padrão" \
            sudo chsh -s "$zsh_path" "$USER"
    else
        log_warning "ZSH já é o shell padrão."
    fi

    # Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        run_silent "Instalando Oh My Zsh" \
            bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    else
        log_warning "Oh My Zsh já instalado."
    fi

    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # Plugin: autosuggestions
    if [[ ! -d "${custom}/plugins/zsh-autosuggestions" ]]; then
        run_silent "Instalando plugin zsh-autosuggestions" \
            git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            "${custom}/plugins/zsh-autosuggestions"
    fi

    # Plugin: syntax-highlighting
    if [[ ! -d "${custom}/plugins/zsh-syntax-highlighting" ]]; then
        run_silent "Instalando plugin zsh-syntax-highlighting" \
            git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "${custom}/plugins/zsh-syntax-highlighting"
    fi

    # Aplica tema e plugins no .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="duellj"/' "$HOME/.zshrc"
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
    fi

    log_success "ZSH + Oh My Zsh configurados (tema: duellj)."
}
