#!/usr/bin/env bash
# =============================================================================
# lib/zsh.sh - Instalação do ZSH + Oh My Zsh
# =============================================================================

install_zsh() {
    log_info "Verificando/instalando ZSH..."

    # Instala ZSH se não existir
    if ! command -v zsh &>/dev/null; then
        sudo apt-get install -y -qq zsh
        log_success "ZSH instalado."
    else
        log_warning "ZSH já está instalado: $(zsh --version)"
    fi

    # Define ZSH como shell padrão
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    local zsh_path
    zsh_path="$(command -v zsh)"

    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_info "Definindo ZSH como shell padrão..."
        chsh -s "$zsh_path" "$USER" || log_warning "Não foi possível alterar o shell padrão automaticamente."
    else
        log_warning "ZSH já é o shell padrão."
    fi

    # Instala Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Instalando Oh My Zsh..."
        # Instalador oficial do Oh My Zsh
        RUNZSH=no CHSH=no sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        log_success "Oh My Zsh instalado."
    else
        log_warning "Oh My Zsh já está instalado."
    fi

    # Plugin zsh-autosuggestions
    local autosuggestions_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    if [[ ! -d "$autosuggestions_dir" ]]; then
        log_info "Instalando plugin zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$autosuggestions_dir"
    fi

    # Plugin zsh-syntax-highlighting
    local syntax_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    if [[ ! -d "$syntax_dir" ]]; then
        log_info "Instalando plugin zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$syntax_dir"
    fi

    # Atualiza plugins no .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i 's/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc" \
            || log_warning "Não foi possível atualizar plugins no .zshrc automaticamente."
    fi

    log_success "ZSH + Oh My Zsh configurados."
}
