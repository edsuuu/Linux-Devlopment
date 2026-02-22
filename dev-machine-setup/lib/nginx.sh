#!/usr/bin/env bash

install_web_server() {
    case "${WEB_SERVER:-nginx}" in
        nginx)  _install_nginx  ;;
        apache) _install_apache ;;
        *)      log_warning "Servidor web desconhecido. Pulando." ;;
    esac
}

_install_nginx() {
    log_info "Configurando Nginx..."

    if command -v nginx &>/dev/null; then
        log_warning "Nginx já instalado: $(nginx -v 2>&1)"
        return 0
    fi

    if [[ "$PKG_MANAGER" == "apt-get" ]]; then
        local arch
        arch="$(dpkg --print-architecture)"

        if [[ ! -f /etc/apt/sources.list.d/nginx.list ]]; then
            run_silent "Adicionando repositório oficial do Nginx" \
                bash -c "curl -fsSL https://nginx.org/keys/nginx_signing.key \
                    | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg && \
                    echo \"deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg arch=${arch}] \
http://nginx.org/packages/${OS_ID} ${OS_CODENAME} nginx\" \
                    | sudo tee /etc/apt/sources.list.d/nginx.list && \
                    sudo apt-get update -y"
        fi

        run_silent "Instalando Nginx" sudo apt-get install -y nginx
    else
        pkg_install "Instalando Nginx" nginx
    fi
    sudo systemctl enable nginx 2>/dev/null || true
    log_success "Nginx instalado: $(nginx -v 2>&1)"
}

_install_apache() {
    log_info "Configurando Apache..."

    if command -v apache2 &>/dev/null; then
        log_warning "Apache já instalado: $(apache2 -v 2>&1 | head -1)"
        return 0
    fi

    run_silent "Instalando Apache" sudo apt-get install -y apache2
    sudo systemctl enable apache2 2>/dev/null || true
    log_success "Apache instalado."
}
