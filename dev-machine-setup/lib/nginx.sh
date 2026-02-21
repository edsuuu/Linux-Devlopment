#!/usr/bin/env bash
# =============================================================================
# lib/nginx.sh - Instalação do Nginx ou Apache
# Controlado pela variável WEB_SERVER ("nginx" | "apache")
# =============================================================================

install_web_server() {
    local server="${WEB_SERVER:-nginx}"

    case "$server" in
        nginx)  install_nginx  ;;
        apache) install_apache ;;
        *)
            log_warning "Servidor web desconhecido: $server. Pulando."
            return 0
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------
install_nginx() {
    log_info "Verificando/instalando Nginx..."

    if command -v nginx &>/dev/null; then
        log_warning "Nginx já está instalado: $(nginx -v 2>&1)"
        return 0
    fi

    # Repositório oficial do Nginx (sempre atualizado)
    local arch
    arch="$(dpkg --print-architecture)"
    local codename
    codename="$(lsb_release -cs)"

    if [[ ! -f /etc/apt/sources.list.d/nginx.list ]]; then
        log_info "Adicionando repositório oficial do Nginx..."
        curl -fsSL https://nginx.org/keys/nginx_signing.key \
            | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

        echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg arch=${arch}] \
http://nginx.org/packages/ubuntu ${codename} nginx" \
            | sudo tee /etc/apt/sources.list.d/nginx.list

        sudo apt-get update -qq
    fi

    sudo apt-get install -y -qq nginx
    sudo systemctl enable nginx 2>/dev/null || true

    log_success "Nginx instalado: $(nginx -v 2>&1)"
}

# -----------------------------------------------------------------------------
# Apache
# -----------------------------------------------------------------------------
install_apache() {
    log_info "Verificando/instalando Apache..."

    if command -v apache2 &>/dev/null; then
        log_warning "Apache já está instalado: $(apache2 -v 2>&1 | head -1)"
        return 0
    fi

    sudo apt-get install -y -qq apache2
    sudo systemctl enable apache2 2>/dev/null || true

    log_success "Apache instalado: $(apache2 -v 2>&1 | head -1)"
}
