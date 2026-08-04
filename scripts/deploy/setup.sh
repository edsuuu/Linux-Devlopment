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

spin() {
    local MSG="$1"
    shift
    local LOG
    LOG="$(mktemp)"
    "$@" > "$LOG" 2>&1 &
    local PID=$!
    local FRAMES='|/-\' I=0
    while kill -0 "$PID" 2> /dev/null; do
        printf '\r[....] %s %s' "$MSG" "${FRAMES:$((I++ % 4)):1}"
        sleep 0.2
    done
    if wait "$PID"; then
        printf '\r[ OK ] %s  \n' "$MSG"
        rm -f "$LOG"
    else
        printf '\r[ERRO] %s\n' "$MSG"
        cat "$LOG" >&2
        rm -f "$LOG"
        return 1
    fi
}

echo "O que voce quer fazer?"
echo "  1) Instalacao completa — servidor (PHP + Composer, Node, nginx, pnpm) e depois o projeto"
echo "  2) Apenas o projeto — servidor ja provisionado"
read -rp "Opcao [1]: " MODE
MODE="${MODE:-1}"

if [ "$MODE" = "1" ]; then
    read -rp "Versao do Node [24]: " NODE_VERSION
    NODE_VERSION="${NODE_VERSION:-24}"

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
        echo "[INFO] Composer ja instalado: $(composer --version) — pulando"
    else
        spin "instalando Composer" bash -c "curl -fsSL https://getcomposer.org/installer | $SUDO php -- --install-dir=/usr/local/bin --filename=composer"
    fi

    spin "adicionando repositorio do Node $NODE_VERSION (nodesource)" \
        bash -c "curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | $SUDO bash -"
    spin "instalando Node" $SUDO apt-get install -y -qq nodejs

    if command -v nginx > /dev/null; then
        echo "[INFO] nginx ja instalado: $(nginx -v 2>&1) — pulando"
    else
        spin "instalando nginx" $SUDO apt-get install -y -qq nginx
        $SUDO systemctl enable --now nginx 2> /dev/null || true
    fi

    echo "[INFO] habilitando pnpm via corepack"
    $SUDO corepack enable
    echo "[INFO] fixe a versao no projeto: \"packageManager\": \"pnpm@10.12.1\" no package.json (sem isso o corepack baixa o pnpm mais novo, que pode exigir Node mais novo)"
fi

read -rp "Nome do projeto: " PROJECT
read -rp "URL SSH do repositorio: " REPOSITORY
read -rp "Branch [main]: " BRANCH
BRANCH="${BRANCH:-main}"
PHP_DEFAULT="$(compgen -c | grep -E '^php([0-9]+\.[0-9]+)?$' | sort -Vu | tail -n 1 || true)"
read -rp "Binario do PHP${PHP_DEFAULT:+ [$PHP_DEFAULT]}: " PHP_BINARY
PHP_BINARY="${PHP_BINARY:-$PHP_DEFAULT}"

if [ -z "$PROJECT" ] || [ -z "$REPOSITORY" ]; then
    echo "[ERRO] nome do projeto e URL do repositorio sao obrigatorios" >&2
    exit 1
fi

if [ -z "$PHP_BINARY" ] || ! command -v "$PHP_BINARY" > /dev/null; then
    echo "[ERRO] binario PHP '$PHP_BINARY' nao encontrado nesta maquina" >&2
    exit 1
fi

echo "[INFO] usando $PHP_BINARY ($("$PHP_BINARY" -r 'echo PHP_VERSION;'))"

PROJECT_DIR="$BASE/$PROJECT"

if [ -d "$PROJECT_DIR" ]; then
    echo "[ERRO] projeto '$PROJECT' ja existe em $PROJECT_DIR — escolha outro nome" >&2
    exit 1
fi

echo "[INFO] criando estrutura em $PROJECT_DIR"
$SUDO mkdir -p "$PROJECT_DIR"/{releases,shared/storage}
$SUDO mkdir -p "$PROJECT_DIR"/shared/storage/{app/public,framework/{cache/data,sessions,testing,views},logs}

$SUDO chown -R "$DEPLOY_USER":www-data "$PROJECT_DIR"
$SUDO chmod -R 2775 "$PROJECT_DIR/shared/storage"
$SUDO usermod -aG www-data "$DEPLOY_USER"

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "deploy-$PROJECT" -f "$HOME/.ssh/id_ed25519" -N ""
    echo "[INFO] deploy key criada — cadastre a chave publica abaixo no GitHub (Settings > Deploy keys):"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

TEMPLATE="$SCRIPT_DIR/deploy.template.sh"
if [ ! -f "$TEMPLATE" ]; then
    BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/scripts/deploy}"
    TEMPLATE="$(mktemp)"
    echo "[INFO] baixando deploy.template.sh"
    curl -fsSL "$BASE_URL/deploy.template.sh" -o "$TEMPLATE"
fi

DEPLOY_SCRIPT="$PWD/deploy-$PROJECT.sh"
sed -e "s|{{PROJECT}}|$PROJECT|g" \
    -e "s|{{REPOSITORY}}|$REPOSITORY|g" \
    -e "s|{{BRANCH}}|$BRANCH|g" \
    -e "s|{{PHP_BINARY}}|$PHP_BINARY|g" \
    "$TEMPLATE" > "$DEPLOY_SCRIPT"
chmod +x "$DEPLOY_SCRIPT"

echo "[INFO] gerado $DEPLOY_SCRIPT — rode-o a cada release"
