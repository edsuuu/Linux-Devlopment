#!/usr/bin/env bash

install_php() {
    local version="${PHP_VERSION:-8.3}"
    log_info "Configurando PHP ${version}..."

    if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        run_silent "Adicionando repositório ondrej/php" \
            bash -c 'sudo add-apt-repository ppa:ondrej/php -y && sudo apt-get update -y'
    else
        run_silent "Atualizando lista de pacotes" sudo apt-get update -y
    fi

    if ! apt-cache show "php${version}" &>/dev/null; then
        local available
        available="$(apt-cache search '^php[0-9]\.' | grep -oP 'php\K[0-9]+\.[0-9]+' | sort -u | tr '\n' ' ')"
        log_error "PHP ${version} não disponível. Versões disponíveis: ${available}"
        log_warning "Usando PHP 8.3 como fallback."
        version="8.3"
        PHP_VERSION="8.3"
    fi

    local php_packages=(
        "php${version}" "php${version}-cli" "php${version}-fpm"
        "php${version}-common" "php${version}-mysql" "php${version}-pgsql"
        "php${version}-sqlite3" "php${version}-curl" "php${version}-mbstring"
        "php${version}-xml" "php${version}-bcmath" "php${version}-zip"
        "php${version}-gd" "php${version}-intl" "php${version}-readline"
        "php${version}-tokenizer" "php${version}-fileinfo"
    )

    local to_install=()
    local already=()

    for pkg in "${php_packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            already+=("$pkg")
        fi
    done

    [[ ${#already[@]} -gt 0 ]] && log_warning "Já instalados: ${already[*]}"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        run_silent "Instalando PHP ${version} e extensões" \
            sudo apt-get install -y "${to_install[@]}"
    else
        log_success "PHP ${version} e extensões já instalados."
    fi

    if ! command -v composer &>/dev/null; then
        run_silent "Instalando Composer" \
            bash -c 'curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer'
    else
        log_warning "Composer já instalado: $(composer --version --no-ansi 2>/dev/null)"
    fi

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
