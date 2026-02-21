#!/usr/bin/env bash
# =============================================================================
# lib/php.sh - Instalação do PHP + Composer + Laravel
# Versão do PHP definida pela variável PHP_VERSION (padrão: 8.3)
# =============================================================================

install_php() {
    local version="${PHP_VERSION:-8.3}"
    log_info "Verificando/instalando PHP ${version}..."

    # Adiciona repositório ondrej/php (PPA oficial com todas as versões)
    if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        log_info "Adicionando repositório ondrej/php..."
        sudo add-apt-repository ppa:ondrej/php -y
        sudo apt-get update -qq
    fi

    local php_packages=(
        "php${version}"
        "php${version}-cli"
        "php${version}-fpm"
        "php${version}-common"
        "php${version}-mysql"
        "php${version}-pgsql"
        "php${version}-sqlite3"
        "php${version}-curl"
        "php${version}-mbstring"
        "php${version}-xml"
        "php${version}-bcmath"
        "php${version}-zip"
        "php${version}-gd"
        "php${version}-intl"
        "php${version}-readline"
        "php${version}-tokenizer"
        "php${version}-fileinfo"
    )

    local to_install=()
    for pkg in "${php_packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo apt-get install -y -qq "${to_install[@]}"
        log_success "PHP ${version} e extensões instalados."
    else
        log_warning "PHP ${version} já está instalado."
    fi

    # ---------------------------------------------------------------------
    # Composer (instalador oficial sempre atualizado)
    # ---------------------------------------------------------------------
    if ! command -v composer &>/dev/null; then
        log_info "Instalando Composer via instalador oficial..."
        local composer_tmp
        composer_tmp="$(mktemp)"

        # Baixa e verifica o instalador oficial do Composer
        curl -sS https://getcomposer.org/installer -o "$composer_tmp"
        php "$composer_tmp" --install-dir=/usr/local/bin --filename=composer
        rm -f "$composer_tmp"

        log_success "Composer instalado: $(composer --version --no-ansi)"
    else
        log_warning "Composer já está instalado: $(composer --version --no-ansi)"
    fi

    # ---------------------------------------------------------------------
    # Laravel Installer (global via Composer)
    # ---------------------------------------------------------------------
    if ! command -v laravel &>/dev/null; then
        log_info "Instalando Laravel Installer globalmente..."
        composer global require laravel/installer --quiet

        # Garante que o bin do Composer global esteja no PATH
        local composer_bin="$HOME/.config/composer/vendor/bin"
        if [[ ! -d "$composer_bin" ]]; then
            composer_bin="$HOME/.composer/vendor/bin"
        fi

        local path_snippet="export PATH=\"\$PATH:${composer_bin}\""

        if ! grep -q "composer/vendor/bin" "$HOME/.zshrc" 2>/dev/null; then
            echo "$path_snippet" >> "$HOME/.zshrc"
        fi
        if ! grep -q "composer/vendor/bin" "$HOME/.bashrc" 2>/dev/null; then
            echo "$path_snippet" >> "$HOME/.bashrc"
        fi

        log_success "Laravel Installer instalado."
    else
        log_warning "Laravel Installer já está instalado: $(laravel --version 2>/dev/null)"
    fi
}
