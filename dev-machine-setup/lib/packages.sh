#!/usr/bin/env bash

install_packages() {
    log_info "Instalando pacotes básicos..."

    case "$PKG_MANAGER" in
        apt-get)
            run_silent "Atualizando lista de pacotes" sudo apt-get update -y
            run_silent "Atualizando pacotes instalados" sudo apt-get upgrade -y
            ;;
        dnf)
            run_silent "Atualizando pacotes" sudo dnf upgrade -y
            ;;
    esac

    local packages=(
        curl wget git unzip zip build-essential
        htop tree jq net-tools openssh-client gnupg
    )

    if [[ "$PKG_MANAGER" == "apt-get" && "$OS_ID" == "ubuntu" ]]; then
        packages+=(software-properties-common apt-transport-https ca-certificates lsb-release)
    elif [[ "$PKG_MANAGER" == "apt-get" && "$OS_ID" == "debian" ]]; then
        packages+=(apt-transport-https ca-certificates lsb-release)
    fi

    local to_install=()
    local already=()

    is_installed() {
        case "$PKG_MANAGER" in
            apt-get) dpkg -s "$1" &>/dev/null ;;
            dnf) rpm -q "$1" &>/dev/null ;;
            pacman) pacman -Qs "^$1$" &>/dev/null ;;
            *) command -v "$1" &>/dev/null ;;
        esac
    }

    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        else
            already+=("$pkg")
        fi
    done

    [[ ${#already[@]} -gt 0 ]] && log_warning "Já instalados: ${already[*]}"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        pkg_install "Instalando ${#to_install[@]} pacotes" "${to_install[@]}"
    else
        log_success "Todos os pacotes básicos já estão instalados."
    fi
}
