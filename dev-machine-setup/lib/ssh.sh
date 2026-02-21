#!/usr/bin/env bash
# =============================================================================
# lib/ssh.sh - Configuração de chave SSH para GitHub
# =============================================================================

setup_ssh() {
    local ssh_dir="$HOME/.ssh"
    local key_file="$ssh_dir/id_ed25519"

    log_info "Configurando chave SSH para GitHub..."

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [[ -f "$key_file" ]]; then
        log_warning "Chave SSH já existe em $key_file. Pulando geração."
    else
        echo -e "\n${CYAN}Digite seu e-mail do GitHub para gerar a chave SSH:${RESET}"
        read -rp "E-mail: " SSH_EMAIL

        if [[ -z "$SSH_EMAIL" ]]; then
            log_warning "E-mail não informado. Pulando configuração SSH."
            return 0
        fi

        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -N "" -f "$key_file"

        # Inicia ssh-agent e adiciona a chave
        eval "$(ssh-agent -s)" > /dev/null 2>&1
        ssh-add "$key_file"

        log_success "Chave SSH gerada: $key_file"
    fi

    # Config para GitHub
    local ssh_config="$ssh_dir/config"
    if ! grep -q "github.com" "$ssh_config" 2>/dev/null; then
        cat >> "$ssh_config" <<EOF

Host github
  User git
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$ssh_config"
        log_success "Config SSH para GitHub adicionado."
    fi

    echo -e "\n${BOLD}${YELLOW}Sua chave SSH pública (adicione no GitHub → Settings → SSH Keys):${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${RESET}"
    cat "${key_file}.pub"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${RESET}\n"
}
