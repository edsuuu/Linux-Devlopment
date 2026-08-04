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

ask() {
    local ANSWER
    read -rp "$1 [s/N]: " ANSWER
    [[ "$ANSWER" =~ ^[sS] ]]
}

# roda um comando em background com spinner; em erro mostra o log do comando
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

# ── provisionamento (cada item é opcional; responda N em tudo para pular) ──

INSTALL_PHP=0
INSTALL_NODE=0
INSTALL_NGINX=0
INSTALL_PNPM=0
NODE_VERSION="22"

if ask "Instalar PHP + Composer"; then
    INSTALL_PHP=1
fi

if ask "Instalar Node"; then
    INSTALL_NODE=1
    read -rp "Versao do Node [22]: " NODE_VERSION_ANSWER
    NODE_VERSION="${NODE_VERSION_ANSWER:-22}"
fi

if ask "Instalar nginx"; then
    INSTALL_NGINX=1
fi

if ask "Instalar pnpm (via corepack, precisa do Node)"; then
    INSTALL_PNPM=1
fi

if [ "$INSTALL_PNPM" -eq 1 ] && [ "$INSTALL_NODE" -eq 0 ] && ! command -v node > /dev/null; then
    echo "[ERRO] pnpm precisa do Node — responda sim para o Node ou instale-o antes" >&2
    exit 1
fi

if [ "$INSTALL_PHP" -eq 1 ] || [ "$INSTALL_NODE" -eq 1 ] || [ "$INSTALL_NGINX" -eq 1 ] || [ "$INSTALL_PNPM" -eq 1 ]; then
    spin "preparando apt" $SUDO apt-get update -qq
    spin "instalando dependencias base" $SUDO apt-get install -y -qq curl ca-certificates gnupg
fi

if [ "$INSTALL_PHP" -eq 1 ]; then
    # ponytail: php-{cli,fpm,...} sem o metapacote "php" — o meta puxaria apache2, e o deploy usa nginx
    spin "instalando PHP (versao disponivel no apt)" $SUDO apt-get install -y -qq php-{cli,fpm,mbstring,xml,curl,mysql,sqlite3,zip,gd,bcmath,intl}
    if ! command -v composer > /dev/null; then
        spin "instalando Composer" bash -c "curl -fsSL https://getcomposer.org/installer | $SUDO php -- --install-dir=/usr/local/bin --filename=composer"
    fi
fi

if [ "$INSTALL_NODE" -eq 1 ]; then
    spin "adicionando repositorio Node $NODE_VERSION (nodesource)" bash -c "curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | $SUDO bash -"
    spin "instalando Node" $SUDO apt-get install -y -qq nodejs
fi

if [ "$INSTALL_NGINX" -eq 1 ]; then
    if command -v nginx > /dev/null; then
        echo "[INFO] nginx ja instalado: $(nginx -v 2>&1) — pulando"
    else
        spin "instalando nginx" $SUDO apt-get install -y -qq nginx
        $SUDO systemctl enable nginx 2>/dev/null || true
    fi
fi

if [ "$INSTALL_PNPM" -eq 1 ]; then
    echo "[INFO] habilitando pnpm via corepack"
    $SUDO corepack enable
    echo "[INFO] fixe a versao no projeto: \"packageManager\": \"pnpm@10.12.1\" no package.json (sem isso o corepack baixa o pnpm mais novo, que pode exigir Node mais novo)"
fi

# ── estrutura do projeto + script de deploy ──

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

# rodando via "bash <(curl ...)" o template nao existe ao lado do script — baixa do repo
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
