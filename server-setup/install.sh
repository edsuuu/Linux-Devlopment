#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
fi

ask() {
    local ANSWER
    read -rp "$1 [s/N]: " ANSWER
    [[ "$ANSWER" =~ ^[sS] ]]
}

INSTALL_PHP=0
INSTALL_NODE=0
INSTALL_NGINX=0
INSTALL_PNPM=0
PHP_VERSION="8.2"
NODE_VERSION="22"

if ask "Instalar PHP + Composer"; then
    INSTALL_PHP=1
    read -rp "Versao do PHP [8.2]: " PHP_VERSION_ANSWER
    PHP_VERSION="${PHP_VERSION_ANSWER:-8.2}"
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

if [ "$INSTALL_PHP" -eq 0 ] && [ "$INSTALL_NODE" -eq 0 ] && [ "$INSTALL_NGINX" -eq 0 ] && [ "$INSTALL_PNPM" -eq 0 ]; then
    echo "[INFO] nada selecionado — saindo"
    exit 0
fi

if [ "$INSTALL_PNPM" -eq 1 ] && [ "$INSTALL_NODE" -eq 0 ] && ! command -v node > /dev/null; then
    echo "[ERRO] pnpm precisa do Node — responda sim para o Node ou instale-o antes" >&2
    exit 1
fi

echo "[INFO] preparando apt"
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq curl ca-certificates gnupg software-properties-common

if [ "$INSTALL_PHP" -eq 1 ]; then
    echo "[INFO] instalando PHP $PHP_VERSION + Composer"
    $SUDO add-apt-repository -y ppa:ondrej/php
    $SUDO apt-get install -y -qq "php$PHP_VERSION"-{cli,fpm,mbstring,xml,curl,mysql,sqlite3,zip,gd,bcmath,intl}
    $SUDO update-alternatives --set php "/usr/bin/php$PHP_VERSION" 2>/dev/null || true
    if ! command -v composer > /dev/null; then
        curl -fsSL https://getcomposer.org/installer | $SUDO "php$PHP_VERSION" -- --install-dir=/usr/local/bin --filename=composer
    fi
fi

if [ "$INSTALL_NODE" -eq 1 ]; then
    echo "[INFO] instalando Node $NODE_VERSION"
    curl -fsSL "https://deb.nodesource.com/setup_$NODE_VERSION.x" | $SUDO bash -
    $SUDO apt-get install -y -qq nodejs
fi

if [ "$INSTALL_NGINX" -eq 1 ]; then
    if command -v nginx > /dev/null; then
        echo "[INFO] nginx ja instalado: $(nginx -v 2>&1) — pulando"
    else
        echo "[INFO] instalando nginx"
        $SUDO apt-get install -y -qq nginx
        $SUDO systemctl enable nginx 2>/dev/null || true
    fi
fi

if [ "$INSTALL_PNPM" -eq 1 ]; then
    echo "[INFO] habilitando pnpm via corepack"
    $SUDO corepack enable
    echo "[INFO] fixe a versao no projeto: \"packageManager\": \"pnpm@10.12.1\" no package.json (sem isso o corepack baixa o pnpm mais novo, que pode exigir Node mais novo)"
fi

echo ""
echo "── instalado ──"
if [ "$INSTALL_PHP" -eq 1 ]; then "php$PHP_VERSION" -v | head -1 && composer --version; fi
if [ "$INSTALL_NODE" -eq 1 ]; then echo "node $(node -v)"; fi
if [ "$INSTALL_NGINX" -eq 1 ]; then nginx -v; fi
if [ "$INSTALL_PNPM" -eq 1 ]; then echo "pnpm habilitado (corepack)"; fi
