#!/usr/bin/env bash
# =============================================================================
# lib/docker.sh - Instalação do Docker + Docker Compose
# Pasta: ~/database | docker-compose.yml baixado do repositório oficial
# =============================================================================

install_docker() {
    log_info "Configurando Docker + Docker Compose..."

    # -------------------------------------------------------------------------
    # Docker Engine via repositório oficial (sem get.docker.com para WSL)
    # -------------------------------------------------------------------------
    if ! command -v docker &>/dev/null; then
        run_silent "Adicionando chave GPG do Docker" \
            bash -c '
                sudo install -m 0755 -d /etc/apt/keyrings
                sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                    -o /etc/apt/keyrings/docker.asc
                sudo chmod a+r /etc/apt/keyrings/docker.asc
            '

        run_silent "Adicionando repositório do Docker" \
            bash -c '
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update -y
            '

        run_silent "Instalando Docker Engine + Compose plugin" \
            sudo apt-get install -y \
                docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin

        sudo usermod -aG docker "$USER"
        log_success "Docker instalado: $(docker --version)"
    else
        log_warning "Docker já instalado: $(docker --version)"
    fi

    # -------------------------------------------------------------------------
    # Inicia Docker (WSL não tem systemd ativo por padrão)
    # -------------------------------------------------------------------------
    if [[ "${IS_WSL:-false}" == "true" ]]; then
        run_silent "Iniciando serviço Docker (WSL)" \
            sudo service docker start || log_warning "Não foi possível iniciar Docker."
    else
        sudo systemctl enable docker 2>/dev/null || true
        sudo systemctl start  docker 2>/dev/null || true
    fi

    # -------------------------------------------------------------------------
    # Pasta ~/database e docker-compose.yml do repositório
    # -------------------------------------------------------------------------
    local db_dir="$HOME/database"

    if [[ ! -d "$db_dir" ]]; then
        mkdir -p "$db_dir"
        log_info "Pasta ~/database criada."
    else
        log_warning "Pasta ~/database já existe."
    fi

    local compose_dest="$db_dir/docker-compose.yml"

    if [[ ! -f "$compose_dest" ]]; then
        run_silent "Baixando docker-compose.yml" \
            curl -fsSL \
                "https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/Docker/docker-compose.yml" \
                -o "$compose_dest"
        log_success "docker-compose.yml salvo em ~/database/"
    else
        log_warning "~/database/docker-compose.yml já existe. Não sobrescrito."
    fi

    # -------------------------------------------------------------------------
    # Sobe os containers automaticamente
    # -------------------------------------------------------------------------
    if [[ -f "$compose_dest" ]]; then
        run_silent "Subindo containers (MySQL, Postgres, MinIO, Mailpit)" \
            docker compose -f "$compose_dest" up -d
    fi

    log_success "Docker configurado. Containers em ~/database/"
}
