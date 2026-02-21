#!/usr/bin/env bash

install_php() {
    local version="${PHP_VERSION:-8.3}"
    log_info "Configurando PHP ${version}..."

    # Garante software-properties-common
    if ! dpkg -s software-properties-common &>/dev/null; then
        run_silent "Instalando software-properties-common" \
            sudo apt-get install -y software-properties-common
    fi

    # Adiciona PPA manualmente (evita bugs do add-apt-repository em WSL)
    run_silent "Adicionando chave GPG do PHP (ondrej)" \
        bash -c '
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14AA40EC0831756756D7F66C4F4EA0AAE5267A6C" \
                | sudo gpg --dearmor -o /etc/apt/keyrings/ondrej-php.gpg
        '

    run_silent "Adicionando repositório ondrej/php" \
        bash -c '
            CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
            echo "deb [signed-by=/etc/apt/keyrings/ondrej-php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${CODENAME} main" \
                | sudo tee /etc/apt/sources.list.d/ondrej-php.list > /dev/null
        '

    run_silent "Atualizando repositórios" sudo apt-get update -y

    # Lista de extensões — filtra o que não existir na distro
    local php_packages=(
        "php${version}" "php${version}-cli" "php${version}-fpm"
        "php${version}-common" "php${version}-mysql" "php${version}-pgsql"
        "php${version}-sqlite3" "php${version}-curl" "php${version}-mbstring"
        "php${version}-xml" "php${version}-bcmath" "php${version}-zip"
        "php${version}-gd" "php${version}-intl"
        "php${version}-readline" "php${version}-tokenizer" "php${version}-fileinfo"
    )

    local to_install=() already=() unavailable=()
    for pkg in "${php_packages[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            already+=("$pkg")
        elif apt-cache show "$pkg" &>/dev/null 2>&1; then
            to_install+=("$pkg")
        else
            unavailable+=("$pkg")
        fi
    done

    [[ ${#already[@]} -gt 0 ]] && log_warning "Já instalados: ${already[*]}"
    [[ ${#unavailable[@]} -gt 0 ]] && log_warning "Não disponíveis nesta distro (ignorados): ${unavailable[*]}"

    if [[ ${#to_install[@]} -eq 0 && ${#already[@]} -gt 0 ]]; then
        log_success "PHP ${version} e extensões já instalados."
    elif [[ ${#to_install[@]} -gt 0 ]]; then
        run_silent "Instalando PHP ${version} e extensões" \
            sudo apt-get install -y "${to_install[@]}" || return 1
    else
        log_error "Nenhum pacote PHP ${version} encontrado no repositório."
        log_warning "Versões disponíveis: $(apt-cache search '^php[0-9]\.' 2>/dev/null | grep -oP 'php\K[0-9]+\.[0-9]+' | sort -u | tr '\n' ' ')"
        return 1
    fi

    # Composer
    if ! command -v php &>/dev/null; then
        log_error "PHP não encontrado no PATH. Pulando Composer e Laravel."
        return 1
    fi

    if ! command -v composer &>/dev/null; then
        run_silent "Instalando Composer" \
            bash -c 'curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer' \
            || { log_error "Falha ao instalar Composer."; return 1; }
    else
        log_warning "Composer já instalado: $(composer --version --no-ansi 2>/dev/null)"
    fi

    # Laravel Installer
    if ! command -v laravel &>/dev/null; then
        run_silent "Instalando Laravel Installer" \
            composer global require laravel/installer --quiet

        local composer_bin
        composer_bin="$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")"
        local path_snippet="export PATH=\"\$PATH:${composer_bin}\""
        for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
            [[ -f "$rc" ]] && ! grep -q "composer/vendor/bin" "$rc" && echo "$path_snippet" >> "$rc"
        done
    else
        log_warning "Laravel Installer já instalado."
    fi

    log_success "PHP ${version}, Composer e Laravel Installer prontos."
}
