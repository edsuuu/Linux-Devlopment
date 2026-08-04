#!/usr/bin/env bash
set -euo pipefail

PROJECT="{{PROJECT}}"
REPOSITORY="{{REPOSITORY}}"
BRANCH="{{BRANCH}}"

BASE="/var/www/projects"
KEEP_RELEASES=3
PHP="{{PHP_BINARY}}"
PROJECT_DIR="$BASE/$PROJECT"

if [ ! -d "$PROJECT_DIR/releases" ]; then
    echo "[ERRO] estrutura de $PROJECT_DIR nao existe — rode o setup.sh antes" >&2
    exit 1
fi

RELEASE="$(date +%Y-%m-%d-%H%M%S)"
RELEASE_DIR="$PROJECT_DIR/releases/$RELEASE"

echo "[INFO] clonando $REPOSITORY ($BRANCH) em $RELEASE_DIR"
git clone --depth 1 --branch "$BRANCH" "$REPOSITORY" "$RELEASE_DIR"
cd "$RELEASE_DIR"

if [ ! -f "$PROJECT_DIR/shared/.env" ]; then
    cp .env.example "$PROJECT_DIR/shared/.env"
    chmod 600 "$PROJECT_DIR/shared/.env"
    echo "[WARN] shared/.env criado a partir do .env.example — revise as credenciais (DB etc.) antes do app subir"
    echo "[WARN] para testar sem MySQL: DB_CONNECTION=sqlite no shared/.env"
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
echo "[INFO] release $RELEASE ativa em $PROJECT_DIR/current"

cd "$PROJECT_DIR/releases"
ls -1 | sort -r | tail -n +$((KEEP_RELEASES + 1)) | while read -r OLD_RELEASE; do
    echo "[INFO] removendo release antiga $OLD_RELEASE"
    rm -rf "$OLD_RELEASE"
done

echo "[INFO] deploy concluido"
