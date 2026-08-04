#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

BASE="/var/www/projects"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="$(id -un)"

SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERRO]${RESET} $*" >&2; }

spin() {
    local MSG="$1"
    shift
    local LOG
    LOG="$(mktemp)"
    "$@" > "$LOG" 2>&1 &
    local PID=$!
    local FRAMES='|/-\' I=0
    while kill -0 "$PID" 2> /dev/null; do
        printf "\r${CYAN}[....]${RESET} %s %s" "$MSG" "${FRAMES:$((I++ % 4)):1}"
        sleep 0.2
    done
    if wait "$PID"; then
        printf "\r${GREEN}[ OK ]${RESET} %s  \n" "$MSG"
        rm -f "$LOG"
    else
        printf "\r${RED}[ERRO]${RESET} %s\n" "$MSG"
        cat "$LOG" >&2
        rm -f "$LOG"
        return 1
    fi
}

select_arrow() {
    local SELECTED="$1"
    local TITLE="$2"
    shift 2
    local OPTIONS=("$@")
    local COUNT="${#OPTIONS[@]}"

    tput civis 2> /dev/null || true

    _draw() {
        echo -e "\n${BOLD}${TITLE}${RESET}"
        for I in "${!OPTIONS[@]}"; do
            if [ "$I" -eq "$SELECTED" ]; then
                echo -e "  ${CYAN}${BOLD}› ${OPTIONS[$I]}${RESET}"
            else
                echo -e "    ${OPTIONS[$I]}"
            fi
        done
    }

    _draw

    while true; do
        local K1="" K2="" K3=""
        IFS= read -rsn1 K1 < /dev/tty
        if [ "$K1" = $'\x1b' ]; then
            IFS= read -rsn1 -t 0.1 K2 < /dev/tty || true
            IFS= read -rsn1 -t 0.1 K3 < /dev/tty || true
            case "${K2}${K3}" in
                '[A') [ "$SELECTED" -gt 0 ] && SELECTED=$((SELECTED - 1)) || true ;;
                '[B') [ "$SELECTED" -lt $((COUNT - 1)) ] && SELECTED=$((SELECTED + 1)) || true ;;
            esac
        elif [ -z "$K1" ]; then
            break
        fi
        for ((L = 0; L < COUNT + 2; L++)); do printf '\033[A\033[2K'; done
        _draw
    done

    tput cnorm 2> /dev/null || true
    echo ""
    ARROW_REPLY="$SELECTED"
}

select_arrow 0 "O que voce quer fazer?" \
    "Instalacao completa  (servidor + projeto)" \
    "Apenas o projeto  (servidor ja provisionado)"
MODE="$ARROW_REPLY"

if [ "$MODE" -eq 0 ]; then
    select_arrow 1 "Qual versao do Node.js?" \
        "Node 26" \
        "Node 24  (LTS atual)" \
        "Node 22  (LTS)" \
        "Node 20  (LTS em manutencao)"
    case "$ARROW_REPLY" in
        0) NODE_VERSION="26" ;;
        1) NODE_VERSION="24" ;;
        2) NODE_VERSION="22" ;;
        3) NODE_VERSION="20" ;;
    esac

    spin "preparando apt" $SUDO apt-get update -qq
    spin "instalando dependencias base" $SUDO apt-get install -y -qq curl ca-certificates gnupg

    spin "instalando PHP + extensoes (versao disponivel no apt)" \
        $SUDO apt-get install -y -qq php-{cli,fpm,mbstring,xml,curl,mysql,sqlite3,zip,gd,bcmath,intl}

    APACHE_PKGS="$(dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 'apache2*' 'libapache2-mod-php*' 2> /dev/null | awk '$2 == "installed" { print $1 }' || true)"
    if [ -n "$APACHE_PKGS" ]; then
        $SUDO systemctl disable --now apache2 2> /dev/null || true
        spin "removendo apache2 (o deploy usa nginx)" $SUDO apt-get purge -y -qq $APACHE_PKGS
        spin "limpando dependencias orfas" $SUDO apt-get autoremove -y -qq
    fi

    if command -v composer > /dev/null; then
        log_info "Composer ja instalado: $(composer --version) — pulando"
    else
        spin "instalando Composer" bash -c "curl -fsSL https://getcomposer.org/installer | $SUDO php -- --install-dir=/usr/local/bin --filename=composer"
    fi

    spin "adicionando repositorio do Node $NODE_VERSION (nodesource)" \
        bash -c "curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | $SUDO bash -"
    spin "instalando Node" $SUDO apt-get install -y -qq nodejs

    if command -v nginx > /dev/null; then
        log_info "nginx ja instalado: $(nginx -v 2>&1) — pulando"
    else
        spin "instalando nginx" $SUDO apt-get install -y -qq nginx
        $SUDO systemctl enable --now nginx 2> /dev/null || true
    fi

    log_info "habilitando pnpm via corepack"
    $SUDO corepack enable
    log_info "fixe a versao no projeto: \"packageManager\": \"pnpm@10.12.1\" no package.json (sem isso o corepack baixa o pnpm mais novo, que pode exigir Node mais novo)"
fi

read -rp "Nome do projeto: " PROJECT
read -rp "URL SSH do repositorio: " REPOSITORY
read -rp "Branch [main]: " BRANCH
BRANCH="${BRANCH:-main}"
read -rp "Dominio do site (vazio = nao configurar o nginx): " DOMAIN

if [ -z "$PROJECT" ] || [ -z "$REPOSITORY" ]; then
    log_error "nome do projeto e URL do repositorio sao obrigatorios"
    exit 1
fi

if command -v php > /dev/null; then
    PHP_BINARY="$(php -r 'echo PHP_BINARY;')"
else
    PHP_BINARY="$(compgen -c | grep -E '^php[0-9]+\.[0-9]+$' | sort -Vu | tail -n 1 || true)"
fi

if [ -z "$PHP_BINARY" ] || ! command -v "$PHP_BINARY" > /dev/null; then
    log_error "PHP nao encontrado — rode a instalacao completa ou instale o PHP antes"
    exit 1
fi

log_info "usando $PHP_BINARY ($("$PHP_BINARY" -r 'echo PHP_VERSION;'))"

PROJECT_DIR="$BASE/$PROJECT"

if [ -d "$PROJECT_DIR" ]; then
    log_error "projeto '$PROJECT' ja existe em $PROJECT_DIR — escolha outro nome"
    exit 1
fi

log_info "criando estrutura em $PROJECT_DIR"
$SUDO mkdir -p "$PROJECT_DIR"/{releases,shared/storage}
$SUDO mkdir -p "$PROJECT_DIR"/shared/storage/{app/public,framework/{cache/data,sessions,testing,views},logs}

$SUDO chown -R "$DEPLOY_USER":www-data "$PROJECT_DIR"
$SUDO chmod -R 2775 "$PROJECT_DIR/shared/storage"
$SUDO usermod -aG www-data "$DEPLOY_USER"

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "deploy-$PROJECT" -f "$HOME/.ssh/id_ed25519" -N ""
    log_info "deploy key criada — cadastre a chave publica abaixo no GitHub (Settings > Deploy keys):"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

if [ -n "$DOMAIN" ]; then
    if command -v nginx > /dev/null; then
        PHP_SHORT="$("$PHP_BINARY" -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
        NGINX_CONF="/etc/nginx/sites-available/$PROJECT"
        FPM_SOCKET="/run/php/php$PHP_SHORT-fpm.sock"

        if [ ! -S "$FPM_SOCKET" ]; then
            FPM_ATIVO="$(ls -1 /run/php/php*-fpm.sock 2> /dev/null | head -n 1 || true)"
            if [ -n "$FPM_ATIVO" ]; then
                log_warn "o CLI e $PHP_SHORT mas o php-fpm no ar e $(basename "$FPM_ATIVO" | sed 's/^php//; s/-fpm.sock$//') — usando $FPM_ATIVO no nginx"
                FPM_SOCKET="$FPM_ATIVO"
            else
                log_warn "nenhum socket php-fpm em /run/php — o site vai dar 502 ate voce subir o php-fpm e revisar o fastcgi_pass em $NGINX_CONF"
            fi
        fi

        $SUDO tee "$NGINX_CONF" > /dev/null << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $PROJECT_DIR/current/public;
    index index.php;
    charset utf-8;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    client_max_body_size 32m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php\$ {
        fastcgi_pass unix:$FPM_SOCKET;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

        $SUDO ln -sfn "$NGINX_CONF" "/etc/nginx/sites-enabled/$PROJECT"

        if $SUDO nginx -t > /dev/null 2>&1; then
            $SUDO systemctl reload nginx
            log_info "nginx servindo $DOMAIN a partir de $PROJECT_DIR/current/public"
        else
            log_error "config do nginx invalida — revise $NGINX_CONF e rode: sudo nginx -t"
        fi
    else
        log_warn "nginx nao esta instalado — pulando a configuracao do site"
    fi
fi

TEMPLATE="$SCRIPT_DIR/deploy.template.sh"
if [ ! -f "$TEMPLATE" ]; then
    BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/scripts/deploy}"
    TEMPLATE="$(mktemp)"
    log_info "baixando deploy.template.sh"
    curl -fsSL "$BASE_URL/deploy.template.sh" -o "$TEMPLATE"
fi

DEPLOY_DIR="$PWD/scripts"
mkdir -p "$DEPLOY_DIR"
DEPLOY_SCRIPT="$DEPLOY_DIR/deploy-$PROJECT.sh"
sed -e "s|{{PROJECT}}|$PROJECT|g" \
    -e "s|{{REPOSITORY}}|$REPOSITORY|g" \
    -e "s|{{BRANCH}}|$BRANCH|g" \
    -e "s|{{PHP_BINARY}}|$PHP_BINARY|g" \
    "$TEMPLATE" > "$DEPLOY_SCRIPT"
chmod +x "$DEPLOY_SCRIPT"

log_info "gerado $DEPLOY_SCRIPT — rode-o a cada release"
