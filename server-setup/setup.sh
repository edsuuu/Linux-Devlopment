#!/usr/bin/env bash
set -euo pipefail

BASE="/var/www/projects"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="$(id -un)"

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
sudo mkdir -p "$PROJECT_DIR"/{releases,shared/storage}
sudo mkdir -p "$PROJECT_DIR"/shared/storage/{app/public,framework/{cache/data,sessions,testing,views},logs}

sudo chown -R "$DEPLOY_USER":www-data "$PROJECT_DIR"
sudo chmod -R 2775 "$PROJECT_DIR/shared/storage"
sudo usermod -aG www-data "$DEPLOY_USER"

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "deploy-$PROJECT" -f "$HOME/.ssh/id_ed25519" -N ""
    echo "[INFO] deploy key criada — cadastre a chave publica abaixo no GitHub (Settings > Deploy keys):"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

DEPLOY_SCRIPT="$SCRIPT_DIR/deploy-$PROJECT.sh"
sed -e "s|{{PROJECT}}|$PROJECT|g" \
    -e "s|{{REPOSITORY}}|$REPOSITORY|g" \
    -e "s|{{BRANCH}}|$BRANCH|g" \
    -e "s|{{PHP_BINARY}}|$PHP_BINARY|g" \
    "$SCRIPT_DIR/deploy.template.sh" > "$DEPLOY_SCRIPT"
chmod +x "$DEPLOY_SCRIPT"

echo "[INFO] gerado $DEPLOY_SCRIPT — rode-o a cada release"
