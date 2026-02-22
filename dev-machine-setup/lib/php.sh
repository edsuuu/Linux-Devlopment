#!/usr/bin/env bash

install_php() {
    local version="${PHP_VERSION:-8.3}"
    log_info "Configurando PHP ${version}..."

    local distro; distro=$(. /etc/os-release && echo "$ID")
    local codename; codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

    setup_repo() {
        if [[ "$distro" == "ubuntu" ]]; then
            log_info "Configurando PPA Ondrej para Ubuntu..."
            sudo apt-get update >/dev/null
            sudo apt-get install -y ca-certificates curl gnupg >/dev/null

            local keyring="/usr/share/keyrings/ondrej-php.gpg"
            sudo rm -f "$keyring"
            sudo curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x4F4EA0AAE5267A6C" \
                | sudo gpg --dearmor -o "$keyring" 2>/dev/null || \
                sudo gpg --no-default-keyring --keyring "$keyring" --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 4F4EA0AAE5267A6C

            echo "deb [signed-by=${keyring}] https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${codename} main" \
                | sudo tee /etc/apt/sources.list.d/php.list > /dev/null

        elif [[ "$distro" == "debian" ]]; then
            log_info "Configurando Repositório Sury para Debian..."
            sudo apt-get update >/dev/null
            sudo apt-get install -y lsb-release ca-certificates apt-transport-https curl >/dev/null
            
            sudo curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
            sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb
            
            sudo sh -c "echo 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${codename} main' > /etc/apt/sources.list.d/php.list"
        else
            log_error "Distribuição não suportada para instalação do PHP: $distro"
            return 1
        fi
        sudo apt-get update -y >/dev/null
    }

    run_silent "Configurando repositório PHP" setup_repo

    local php_packages=(
        "php${version}" "php${version}-cli" "php${version}-fpm"
        "php${version}-common" "php${version}-mysql" "php${version}-pgsql"
        "php${version}-sqlite3" "php${version}-curl" "php${version}-mbstring"
        "php${version}-xml" "php${version}-bcmath" "php${version}-zip"
        "php${version}-gd" "php${version}-intl" "php${version}-intl"
        "php${version}-readline" "php${version}-tokenizer" "php${version}-fileinfo"
    )

    run_silent "Instalando PHP ${version} e extensões" \
        sudo apt-get install -y "${php_packages[@]}" || return 1

    if ! command -v composer &>/dev/null; then
        run_silent "Instalando Composer" \
            bash -c 'curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer'
    fi

    if ! command -v laravel &>/dev/null; then
        run_silent "Instalando Laravel Installer" \
            composer global require laravel/installer --quiet
        
        local composer_bin; composer_bin=$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")
        local path_snippet="export PATH=\"\$PATH:${composer_bin}\""
        for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
            [[ -f "$rc" ]] && ! grep -q "composer/vendor/bin" "$rc" && echo "$path_snippet" >> "$rc"
        done
    fi

    log_success "PHP ${version}, Composer e Laravel Installer prontos"
}