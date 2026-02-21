#!/usr/bin/env bash

setup_ssh() {
    local key_file="$HOME/.ssh/id_ed25519"

    log_info "Configurando chave SSH para GitHub..."

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$key_file" ]]; then
        log_warning "Chave SSH já existe: $key_file"
    else
        echo -e "\n${CYAN}Digite seu e-mail do GitHub para gerar a chave SSH:${RESET}"
        read -rp "E-mail: " SSH_EMAIL

        if [[ -z "$SSH_EMAIL" ]]; then
            log_warning "E-mail não informado. Pulando configuração SSH."
            return 0
        fi

        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -N "" -f "$key_file"
        eval "$(ssh-agent -s)" > /dev/null 2>&1
        ssh-add "$key_file"
        log_success "Chave SSH gerada."
    fi

    local ssh_config="$HOME/.ssh/config"
    if ! grep -q "github.com" "$ssh_config" 2>/dev/null; then
        cat >> "$ssh_config" <<EOF

Host github
  User git
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$ssh_config"
    fi

    echo -e "\n${BOLD}${YELLOW}Chave pública SSH (adicione no GitHub → Settings → SSH Keys):${RESET}"
    echo -e "${CYAN}────────────────────────────────────────${RESET}"
    cat "${key_file}.pub"
    echo -e "${CYAN}────────────────────────────────────────${RESET}\n"
}
