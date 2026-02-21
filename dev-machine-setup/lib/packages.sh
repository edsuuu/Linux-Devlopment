#!/usr/bin/env bash
# =============================================================================
# lib/packages.sh - Instalação de pacotes básicos do sistema
# =============================================================================

install_packages() {
    log_info "Atualizando sistema e instalando pacotes básicos..."

    sudo apt-get update -qq
    sudo apt-get upgrade -y -qq

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
            log_warning "Pacote já instalado: $pkg"
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo apt-get install -y -qq "${to_install[@]}"
        log_success "Pacotes instalados: ${to_install[*]}"
    else
        log_success "Todos os pacotes básicos já estão instalados."
    fi
}
