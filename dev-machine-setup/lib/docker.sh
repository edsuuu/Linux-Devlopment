#!/usr/bin/env bash
# =============================================================================
# lib/docker.sh - Instalação do Docker + Docker Compose
# =============================================================================

install_docker() {
    log_info "Verificando/instalando Docker..."

    # -------------------------------------------------------------------------
    # Docker Engine
    # -------------------------------------------------------------------------
    if command -v docker &>/dev/null; then
        log_warning "Docker já está instalado: $(docker --version)"
    else
        log_info "Instalando Docker via script oficial get.docker.com..."
        # Script oficial do Docker - sempre pega a versão mais recente estável
        curl -fsSL https://get.docker.com | sh

        # Adiciona usuário ao grupo docker (evita necessidade de sudo)
        sudo usermod -aG docker "$USER"
        log_success "Docker instalado: $(docker --version)"
    fi

    # -------------------------------------------------------------------------
    # Docker Compose (plugin oficial)
    # -------------------------------------------------------------------------
    if docker compose version &>/dev/null 2>&1; then
        log_warning "Docker Compose (plugin) já instalado: $(docker compose version)"
    else
        log_info "Instalando Docker Compose plugin..."
        # O plugin é instalado junto com docker-ce via get.docker.com
        # Caso não tenha sido instalado, instala via apt
        sudo apt-get install -y -qq docker-compose-plugin
        log_success "Docker Compose instalado: $(docker compose version)"
    fi

    # -------------------------------------------------------------------------
    # Iniciar Docker no WSL (systemd pode não estar ativo)
    # -------------------------------------------------------------------------
    if [[ "${IS_WSL:-false}" == "true" ]]; then
        log_info "WSL detectado. Iniciando serviço Docker manualmente..."
        sudo service docker start 2>/dev/null || log_warning "Não foi possível iniciar o Docker automaticamente no WSL."
    else
        sudo systemctl enable docker 2>/dev/null || true
        sudo systemctl start  docker 2>/dev/null || true
    fi

    # -------------------------------------------------------------------------
    # Pasta ~/docker e docker-compose.yml padrão
    # -------------------------------------------------------------------------
    local docker_dir="$HOME/docker"

    if [[ ! -d "$docker_dir" ]]; then
        mkdir -p "$docker_dir"
        log_info "Pasta ~/docker criada."
    else
        log_warning "Pasta ~/docker já existe."
    fi

    local compose_dest="$docker_dir/docker-compose.yml"

    if [[ ! -f "$compose_dest" ]]; then
        local compose_src="${SCRIPT_DIR}/docker/docker-compose.yml"
        if [[ -f "$compose_src" ]]; then
            cp "$compose_src" "$compose_dest"
            log_success "docker-compose.yml copiado para ~/docker/"
        else
            log_warning "docker-compose.yml de origem não encontrado. Pulando cópia."
        fi
    else
        log_warning "~/docker/docker-compose.yml já existe. Não sobrescrito."
    fi

    # -------------------------------------------------------------------------
    # Sobe os containers automaticamente
    # -------------------------------------------------------------------------
    if [[ -f "$compose_dest" ]]; then
        log_info "Subindo containers com docker compose..."
        if docker compose -f "$compose_dest" up -d; then
            log_success "Containers iniciados com sucesso."
        else
            log_warning "Não foi possível subir os containers. Verifique ~/docker/docker-compose.yml"
        fi
    fi
}
