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

    # Inicia o serviço
    if [[ "${IS_WSL:-false}" == "true" ]]; then
        run_silent "Iniciando Docker (WSL)" \
            sudo service docker start || log_warning "Não foi possível iniciar Docker."
    else
        sudo systemctl start docker 2>/dev/null || true
        sudo systemctl enable docker 2>/dev/null || true
    fi

    # Pasta e docker-compose.yml
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

    if [[ -f "$compose_dest" ]]; then
        run_silent "Subindo containers" \
            sudo docker compose -f "$compose_dest" up -d \
            || log_warning "Falha ao subir containers. Execute: sudo docker compose -f ~/database/docker-compose.yml up -d"
    fi

    log_success "Docker pronto. Containers em ~/database/"
}
