#!/usr/bin/env bash
# Uso: bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/dev-machine-setup/setup.sh)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}    $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET}   $*" >&2; }

BACKGROUND_PIDS=()

cleanup() {
    local pids=("${BACKGROUND_PIDS[@]}")
    if [[ ${#pids[@]} -gt 0 ]]; then
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi
    # Limpa a linha atual no terminal para evitar poluição visual
    printf "\r\033[2K" >/dev/tty
}

trap cleanup EXIT INT TERM

run_silent() {
    local msg="$1"; shift
    local log_file; log_file="$(mktemp)"

    "$@" >"$log_file" 2>&1 &
    local pid=$!

    # Spinner roda num subshell próprio — isolado do set -e
    (
        local spinchars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local i=0
        while true; do
            printf "\033[2K\r${CYAN}  %s${RESET}  %s" \
                "${spinchars[$((i % 10))]}" "$msg" >/dev/tty
            i=$(( i + 1 ))
            sleep 0.1
        done
    ) &
    local spinner_pid=$!
    BACKGROUND_PIDS+=("$spinner_pid")

    wait "$pid"
    local exit_code=$?

    kill "$spinner_pid" 2>/dev/null || true
    wait "$spinner_pid" 2>/dev/null || true
    printf "\033[2K\r" >/dev/tty

    if [[ $exit_code -eq 0 ]]; then
        log_success "$msg"
        rm -f "$log_file"
    else
        log_error "Falha: $msg"
        cat "$log_file"
        rm -f "$log_file"
        return 1
    fi
}

select_arrow() {
    local title="$1"; shift
    local options=("$@")
    local selected=0
    local num="${#options[@]}"

    tput civis 2>/dev/null || true

    _draw() {
        echo -e "\n${BOLD}${title}${RESET}"
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${CYAN}${BOLD}› ${options[$i]}${RESET}"
            else
                echo -e "    ${options[$i]}"
            fi
        done
    }

    _draw

    while true; do
        local k1 k2 k3
        IFS= read -rsn1 k1 </dev/tty
        if [[ "$k1" == $'\x1b' ]]; then
            IFS= read -rsn1 -t 0.1 k2 </dev/tty || true
            IFS= read -rsn1 -t 0.1 k3 </dev/tty || true
            case "${k2}${k3}" in
                '[A') [[ $selected -gt 0 ]] && selected=$((selected - 1)) || true ;;
                '[B') [[ $selected -lt $((num - 1)) ]] && selected=$((selected + 1)) || true ;;
            esac
        elif [[ "$k1" == '' || "$k1" == $'\n' ]]; then
            break
        fi
        for (( l=0; l < num + 2; l++ )); do printf '\033[A\033[2K'; done
        _draw
    done

    tput cnorm 2>/dev/null || true
    echo ""
    ARROW_REPLY=$selected
}

export -f run_silent log_info log_success log_warning log_error

detect_environment() {
    if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
        IS_WSL=true; log_info "Ambiente WSL detectado."
    else
        IS_WSL=false; log_info "Ambiente Linux nativo detectado."
    fi
    export IS_WSL
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_module() {
    local path="${SCRIPT_DIR}/lib/${1}.sh"
    [[ -f "$path" ]] && source "$path" || { log_error "Módulo não encontrado: $path"; exit 1; }
}

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/dev-machine-setup}"
TEMP_DIR="$(mktemp -d)"

download_module() {
    local url="${BASE_URL}/lib/${1}.sh"
    local dest="${TEMP_DIR}/lib/${1}.sh"
    mkdir -p "${TEMP_DIR}/lib"
    # Força redownload sempre para evitar cache stale no modo remoto
    log_info "Baixando módulo: ${1}.sh"
    curl -fsSL "$url" -o "$dest" || { log_error "Falha ao baixar: $url"; exit 1; }
}

if [[ -d "${SCRIPT_DIR}/lib" ]]; then
    USE_LOCAL=true
else
    USE_LOCAL=false
    SCRIPT_DIR="$TEMP_DIR"
    log_info "Modo remoto: baixando módulos..."
    for mod in packages zsh node php nginx docker folders ssh; do
        download_module "$mod"
    done
fi

echo -e "\n${BOLD}${CYAN}================================================${RESET}"
echo -e "${BOLD}${CYAN}   dev-machine-setup - Configuração Automática   ${RESET}"
echo -e "${BOLD}${CYAN}================================================${RESET}\n"

detect_environment

echo -e "${BOLD}${YELLOW}Insira sua senha sudo (pedida apenas uma vez):${RESET}"
sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
BACKGROUND_PIDS+=("$SUDO_KEEPALIVE_PID")

select_arrow "Instalar ZSH + Oh My Zsh?" \
    "Sim  (recomendado)" \
    "Não"
[[ $ARROW_REPLY -eq 0 ]] && INSTALL_ZSH=true || INSTALL_ZSH=false
export INSTALL_ZSH

select_arrow "Qual servidor web você deseja instalar?" \
    "Nginx  (recomendado)" "Apache" "Nenhum"

case $ARROW_REPLY in
    0) WEB_SERVER="nginx" ;;
    1) WEB_SERVER="apache" ;;
    2) WEB_SERVER="none" ;;
esac
export WEB_SERVER

select_arrow "Qual versão do PHP instalar?" \
    "PHP 8.5  (quando disponível no PPA)" \
    "PHP 8.4  (estável)" \
    "PHP 8.3  (estável - recomendado)"

case $ARROW_REPLY in
    0) PHP_VERSION="8.5" ;;
    1) PHP_VERSION="8.4" ;;
    2) PHP_VERSION="8.3" ;;
esac
export PHP_VERSION

select_arrow "Qual versão do Node.js instalar?" \
    "Node 25" \
    "Node 24  (LTS atual)" \
    "Node 23" \
    "Node 22  (LTS ativo - recomendado)" \
    "Node 20  (LTS manutenção)"

case $ARROW_REPLY in
    0) NODE_VERSION="25" ;;
    1) NODE_VERSION="24" ;;
    2) NODE_VERSION="23" ;;
    3) NODE_VERSION="22" ;;
    4) NODE_VERSION="20" ;;
esac
export NODE_VERSION

FAILED_MODULES=()

run_module() {
    local name="$1" fn="$2"
    load_module "$name"
    set +e
    $fn
    local code=$?
    set -e
    if [[ $code -ne 0 ]]; then
        log_warning "Módulo '${name}' falhou (código ${code}). Será retentado no final."
        FAILED_MODULES+=("${name}:${fn}")
    fi
}

run_module "packages" "install_packages"
[[ "$INSTALL_ZSH" == "true" ]] && run_module "zsh" "install_zsh"
run_module "node"     "install_node"
run_module "php"      "install_php"
run_module "folders"  "setup_folders"
[[ "$WEB_SERVER" != "none" ]] && run_module "nginx" "install_web_server"
run_module "docker" "install_docker"
run_module "ssh"    "setup_ssh"

if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
    echo -e "\n${BOLD}${YELLOW}Retentando módulos com falha...${RESET}"
    STILL_FAILED=()
    for entry in "${FAILED_MODULES[@]}"; do
        mod_name="${entry%%:*}"; mod_fn="${entry##*:}"
        log_info "Retentando: ${mod_name}..."
        load_module "$mod_name"
        set +e; $mod_fn; retry_code=$?; set -e
        if [[ $retry_code -ne 0 ]]; then
            STILL_FAILED+=("$mod_name")
            log_error "Módulo '${mod_name}' falhou novamente."
        else
            log_success "Módulo '${mod_name}' concluído na segunda tentativa."
        fi
    done
    [[ ${#STILL_FAILED[@]} -gt 0 ]] && \
        echo -e "\n${RED}Atenção manual necessária: ${STILL_FAILED[*]}${RESET}"
fi

[[ "$USE_LOCAL" == "false" ]] && rm -rf "$TEMP_DIR"
kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

echo -e "\n${BOLD}${GREEN}================================================${RESET}"
echo -e "${BOLD}${GREEN}   Configuração concluída!                       ${RESET}"
echo -e "${BOLD}${GREEN}================================================${RESET}"
echo -e ""
echo -e "  • Projetos: ${BOLD}/var/www/projects${RESET}  →  ~/projects"
echo -e "  • Docker:   ${BOLD}~/database/docker-compose.yml${RESET}"
echo -e "  • Containers: MySQL · Postgres · MinIO · Mailpit"
echo -e ""
echo -e "${YELLOW}Entrando no ZSH...${RESET}\n"

exec zsh
