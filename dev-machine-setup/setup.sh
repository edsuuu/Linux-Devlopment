#!/usr/bin/env bash
# =============================================================================
# dev-machine-setup - Script principal de configuração do ambiente
# Uso: bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/dev-machine-setup/setup.sh)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Cores para logs
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# -----------------------------------------------------------------------------
# Funções de log
# -----------------------------------------------------------------------------
log_info()    { echo -e "${CYAN}[INFO]${RESET}    $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET}   $*" >&2; }

# Executa comando em background com spinner animado
# Uso: run_silent "Mensagem" comando arg1 arg2 ...
run_silent() {
    local msg="$1"
    shift
    local log_file
    log_file="$(mktemp)"
    local spinchars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    "$@" >"$log_file" 2>&1 &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        local char="${spinchars:$((i % ${#spinchars})):1}"
        printf "\r${CYAN}  %s${RESET}  %s" "$char" "$msg"
        i=$((i + 1))
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?
    printf "\r\033[K"  # limpa linha do spinner

    if [[ $exit_code -eq 0 ]]; then
        log_success "$msg"
    else
        log_error "Falha: $msg"
        cat "$log_file" >&2
    fi

    rm -f "$log_file"
    return $exit_code
}
export -f run_silent log_info log_success log_warning log_error

# -----------------------------------------------------------------------------
# Detecção de ambiente
# -----------------------------------------------------------------------------
detect_environment() {
    if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
        IS_WSL=true
        log_info "Ambiente WSL detectado."
    else
        IS_WSL=false
        log_info "Ambiente Linux nativo detectado."
    fi
    export IS_WSL
}

# -----------------------------------------------------------------------------
# Carregamento dos módulos
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_module() {
    local module="$1"
    local path="${SCRIPT_DIR}/lib/${module}.sh"
    if [[ -f "$path" ]]; then
        # shellcheck source=/dev/null
        source "$path"
    else
        log_error "Módulo não encontrado: $path"
        exit 1
    fi
}

# Quando executado via curl, os módulos são baixados dinamicamente
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/dev-machine-setup}"
TEMP_DIR="$(mktemp -d)"

download_module() {
    local module="$1"
    local url="${BASE_URL}/lib/${module}.sh"
    local dest="${TEMP_DIR}/lib/${module}.sh"

    mkdir -p "${TEMP_DIR}/lib"

    if [[ ! -f "$dest" ]]; then
        log_info "Baixando módulo: ${module}.sh"
        curl -fsSL "$url" -o "$dest" || {
            log_error "Falha ao baixar módulo: $url"
            exit 1
        }
    fi
}

# Decide se usa arquivos locais ou baixa via curl
if [[ -d "${SCRIPT_DIR}/lib" ]]; then
    USE_LOCAL=true
else
    USE_LOCAL=false
    SCRIPT_DIR="$TEMP_DIR"
    log_info "Modo remoto (curl): baixando módulos..."
    for mod in packages zsh node php nginx docker folders ssh; do
        download_module "$mod"
    done
fi

# -----------------------------------------------------------------------------
# Início da configuração
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}================================================${RESET}"
echo -e "${BOLD}${CYAN}   dev-machine-setup - Configuração Automática   ${RESET}"
echo -e "${BOLD}${CYAN}================================================${RESET}\n"

detect_environment

# -----------------------------------------------------------------------------
# Servidor web
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}Qual servidor web você deseja instalar?${RESET}"
echo "  1) Nginx  (recomendado)"
echo "  2) Apache"
echo "  3) Nenhum"
read -rp "Escolha [1-3] (padrão: 1): " WEB_SERVER_CHOICE
WEB_SERVER_CHOICE="${WEB_SERVER_CHOICE:-1}"

case "$WEB_SERVER_CHOICE" in
    1) WEB_SERVER="nginx" ;;
    2) WEB_SERVER="apache" ;;
    3) WEB_SERVER="none" ;;
    *) WEB_SERVER="nginx" ;;
esac
export WEB_SERVER

# -----------------------------------------------------------------------------
# Versão do PHP
# -----------------------------------------------------------------------------
read -rp "Versão do PHP a instalar (padrão: 8.3): " PHP_VERSION
PHP_VERSION="${PHP_VERSION:-8.3}"
export PHP_VERSION

# -----------------------------------------------------------------------------
# Execução dos módulos
# -----------------------------------------------------------------------------
load_module "packages"
install_packages

load_module "zsh"
install_zsh

load_module "node"
install_node

load_module "php"
install_php

load_module "folders"
setup_folders

if [[ "$WEB_SERVER" != "none" ]]; then
    load_module "nginx"
    install_web_server
fi

load_module "docker"
install_docker

load_module "ssh"
setup_ssh

# -----------------------------------------------------------------------------
# Limpeza
# -----------------------------------------------------------------------------
if [[ "$USE_LOCAL" == "false" ]]; then
    rm -rf "$TEMP_DIR"
fi

# -----------------------------------------------------------------------------
# Resumo final
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}================================================${RESET}"
echo -e "${BOLD}${GREEN}   Configuração concluída com sucesso!           ${RESET}"
echo -e "${BOLD}${GREEN}================================================${RESET}"
echo -e ""
echo -e "${CYAN}Resumo:${RESET}"
echo -e "  • Projetos em:  ${BOLD}/var/www/projects${RESET}  (symlink: ~/projects)"
echo -e "  • Docker em:    ${BOLD}~/database/docker-compose.yml${RESET}"
echo -e "  • Containers:   ${BOLD}MySQL · Postgres · MinIO · Mailpit${RESET}"
echo -e ""
echo -e "${YELLOW}Reiniciando no ZSH...${RESET}\n"

# Inicia ZSH ao finalizar
exec zsh
