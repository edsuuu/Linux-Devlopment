#!/usr/bin/env bash

install_php() {
    local version="${PHP_VERSION:-8.3}"
    log_info "Configurando PHP ${version}..."

    setup_repo() {
        if [[ "$OS_ID" == "ubuntu" ]]; then
            log_info "Configurando PPA Ondrej para Ubuntu..."
            sudo apt-get update >/dev/null
            sudo apt-get install -y ca-certificates curl gnupg >/dev/null

            local keyring="/usr/share/keyrings/ondrej-php.gpg"
            sudo rm -f "$keyring"
            sudo curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x4F4EA0AAE5267A6C" \
                | sudo gpg --dearmor -o "$keyring" 2>/dev/null || \
                sudo gpg --no-default-keyring --keyring "$keyring" --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 4F4EA0AAE5267A6C

            echo "deb [signed-by=${keyring}] https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${OS_CODENAME} main" \
                | sudo tee /etc/apt/sources.list.d/php.list > /dev/null

        elif [[ "$OS_ID" == "debian" ]]; then
            log_info "Configurando Repositório Sury para Debian..."
            sudo apt-get update >/dev/null
            sudo apt-get install -y lsb-release ca-certificates apt-transport-https curl >/dev/null
            
            sudo curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
            sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb
            
            sudo sh -c "echo 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${OS_CODENAME} main' > /etc/apt/sources.list.d/php.list"
        else
            log_warning "Distribuição não suportada automaticamente para repositório PHP customizado: $OS_ID. Tentando pacotes padrão."
            return 0
        fi
        sudo apt-get update -y >/dev/null
    }
    export -f setup_repo

    run_silent "Configurando repositório PHP" setup_repo

    local php_packages=(
        "php${version}" "php${version}-cli" "php${version}-fpm"
        "php${version}-common" "php${version}-mysql" "php${version}-pgsql"
        "php${version}-sqlite3" "php${version}-curl" "php${version}-mbstring"
        "php${version}-xml" "php${version}-bcmath" "php${version}-zip"
        "php${version}-gd" "php${version}-intl"
        "php${version}-readline" "php${version}-tokenizer" "php${version}-fileinfo"
    )

    pkg_install "Instalando PHP ${version} e extensões" "${php_packages[@]}" || return 1

    if ! command -v composer &>/dev/null; then
        run_silent "Instalando Composer" \
            bash -c 'curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer'
    fi

    if ! command -v laravel &>/dev/null; then
        # Garante que o composer está acessível se acabou de ser instalado
        export PATH="/usr/local/bin:$PATH"
        run_silent "Instalando Laravel Installer" \
            composer global require laravel/installer --quiet
        
        local composer_bin; composer_bin=$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")
        local path_snippet="export PATH=\"\$PATH:${composer_bin}\""
        for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
            [[ -f "$rc" ]] && ! grep -q "composer/vendor/bin" "$rc" && echo "$path_snippet" >> "$rc"
        done
        # Atualiza PATH atual para o resto do script
        export PATH="$PATH:${composer_bin}"
    fi

    log_success "PHP ${version}, Composer e Laravel Installer prontos"
}