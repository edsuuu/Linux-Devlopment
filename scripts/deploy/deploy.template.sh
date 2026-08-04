#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_ok() { echo -e "${GREEN}[ OK ]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERRO]${RESET} $*" >&2; }

PROJECT="{{PROJECT}}"
REPOSITORY="{{REPOSITORY}}"
BRANCH="{{BRANCH}}"

BASE="/var/www/projects"
KEEP_RELEASES=3
PHP="{{PHP_BINARY}}"
PROJECT_DIR="$BASE/$PROJECT"

if [ ! -d "$PROJECT_DIR/releases" ]; then
    log_error "estrutura de $PROJECT_DIR nao existe — rode o setup.sh antes"
    exit 1
fi

RELEASE="$(date +%Y-%m-%d-%H%M%S)"
RELEASE_DIR="$PROJECT_DIR/releases/$RELEASE"

log_info "clonando $REPOSITORY ($BRANCH) em $RELEASE_DIR"
git clone --depth 1 --branch "$BRANCH" "$REPOSITORY" "$RELEASE_DIR"
cd "$RELEASE_DIR"

if [ ! -f "$PROJECT_DIR/shared/.env" ]; then
    cp .env.example "$PROJECT_DIR/shared/.env"
    chmod 600 "$PROJECT_DIR/shared/.env"
    log_warn "shared/.env criado a partir do .env.example — revise as credenciais (DB etc.) antes do app subir"
    log_warn "para testar sem MySQL: DB_CONNECTION=sqlite no shared/.env"
fi

rm -rf storage
ln -s "$PROJECT_DIR/shared/storage" storage
cp "$PROJECT_DIR/shared/.env" .env
chmod 600 .env
ln -sfn "$PROJECT_DIR/shared/storage/app/public" public/storage

composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

if ! grep -qE '^APP_KEY=.+$' .env; then
    "$PHP" artisan key:generate --force
    cp .env "$PROJECT_DIR/shared/.env"
    chmod 600 "$PROJECT_DIR/shared/.env"
fi

if [ -f pnpm-lock.yaml ]; then
    pnpm install --frozen-lockfile
    pnpm run build
elif [ -f package.json ]; then
    npm ci
    npm run build
    rm -rf node_modules
fi

sudo chgrp -R www-data bootstrap/cache
sudo chmod -R 2775 bootstrap/cache

"$PHP" artisan migrate --force
"$PHP" artisan optimize

ln -sfn "$RELEASE_DIR" "$PROJECT_DIR/current"
log_ok "release $RELEASE ativa em $PROJECT_DIR/current"

reload_fpm() {
    local SERVICE
    SERVICE="php$("$PHP" -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')-fpm"

    if sudo systemctl reload "$SERVICE" 2> /dev/null; then
        log_ok "$SERVICE recarregado: opcache e realpath cache limpos"
        return 0
    fi

    SERVICE="$(systemctl list-units --plain --no-legend --state=active 'php*-fpm.service' 2> /dev/null | awk '{ print $1 }' | head -n 1 || true)"
    if [ -n "$SERVICE" ] && sudo systemctl reload "$SERVICE" 2> /dev/null; then
        log_ok "$SERVICE recarregado: opcache e realpath cache limpos"
        return 0
    fi

    log_warn "nao consegui recarregar o php-fpm — o site pode servir codigo da release anterior ate o cache expirar"
}

reload_fpm

cd "$PROJECT_DIR/releases"
ls -1 | sort -r | tail -n +$((KEEP_RELEASES + 1)) | while read -r OLD_RELEASE; do
    log_info "removendo release antiga $OLD_RELEASE"
    rm -rf "$OLD_RELEASE"
done

log_ok "deploy concluido"
