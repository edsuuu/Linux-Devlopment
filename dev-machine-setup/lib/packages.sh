#!/usr/bin/env bash
# =============================================================================
# lib/packages.sh - Instalação de pacotes básicos do sistema
# =============================================================================

install_packages() {
    log_info "Iniciando atualização e instalação de pacotes básicos..."

    run_silent "Atualizando lista de pacotes (apt update)" \
        sudo apt-get update -y

    run_silent "Atualizando pacotes instalados (apt upgrade)" \
        sudo apt-get upgrade -y

    local packages=(
        curl
        wget
        git
        unzip
        zip
        build-essential
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
        htop
        tree
        jq
        net-tools
        openssh-client
    )

    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            log_warning "Já instalado: $pkg"
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Instalando: ${to_install[*]}"
        run_silent "Instalando pacotes básicos (${#to_install[@]} pacotes)" \
            sudo apt-get install -y "${to_install[@]}"
    else
        log_success "Todos os pacotes básicos já estão instalados."
    fi
}
