#!/usr/bin/env bash

install_packages() {
    log_info "Instalando pacotes básicos..."

    run_silent "Atualizando lista de pacotes" sudo apt-get update -y
    run_silent "Atualizando pacotes instalados" sudo apt-get upgrade -y

    local packages=(
        curl wget git unzip zip build-essential
        software-properties-common apt-transport-https
        ca-certificates gnupg lsb-release
        htop tree jq net-tools openssh-client
    )

    local to_install=()
    local already=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            already+=("$pkg")
        fi
    done

    [[ ${#already[@]} -gt 0 ]] && log_warning "Já instalados: ${already[*]}"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        run_silent "Instalando ${#to_install[@]} pacotes" \
            sudo apt-get install -y "${to_install[@]}"
    else
        log_success "Todos os pacotes básicos já estão instalados."
    fi
}
