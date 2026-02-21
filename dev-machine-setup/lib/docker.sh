#!/usr/bin/env bash

install_docker() {
    log_info "Configurando Docker + Docker Compose..."

    if ! command -v docker &>/dev/null; then
        run_silent "Instalando dependências do Docker" \
            sudo apt-get install -y ca-certificates curl

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

    start_docker() {
        if sudo service docker start 2>/dev/null; then return 0; fi
        if sudo /etc/init.d/docker start 2>/dev/null; then return 0; fi
        if sudo systemctl start docker 2>/dev/null; then return 0; fi
        return 1
    }

    if docker info &>/dev/null; then
        log_warning "Docker já está rodando."
    else
        run_silent "Iniciando Docker" start_docker || {
            log_error "Não foi possível iniciar Docker. Pulando containers."
            return 1
        }
    fi

    local db_dir="$HOME/database"
    [[ ! -d "$db_dir" ]] && mkdir -p "$db_dir" && log_info "Pasta ~/database criada."

    local compose_url="https://raw.githubusercontent.com/edsuuu/ubuntu-info/refs/heads/main/Docker/docker-compose.yml"
    local compose_dest="$db_dir/docker-compose.yml"

    if [[ ! -f "$compose_dest" ]]; then
        run_silent "Baixando docker-compose.yml" \
            curl -fsSL "$compose_url" -o "$compose_dest"
    else
        log_warning "~/database/docker-compose.yml já existe."
    fi

    # Sobe cada container individualmente — falha em um não para os outros
    if [[ -f "$compose_dest" ]]; then
        log_info "Subindo containers..."
        local services
        mapfile -t services < <(sudo docker compose -f "$compose_dest" config --services 2>/dev/null)

        for service in "${services[@]}"; do
            local tmp; tmp="$(mktemp)"
            sudo docker compose -f "$compose_dest" up -d "$service" >"$tmp" 2>&1 \
                && log_success "Container iniciado: ${service}" \
                || log_warning "Falha ao subir '${service}'. Verifique: sudo docker compose -f ~/database/docker-compose.yml up -d ${service}"
            rm -f "$tmp"
        done
    fi

    log_success "Docker pronto. Containers em ~/database/"
}
