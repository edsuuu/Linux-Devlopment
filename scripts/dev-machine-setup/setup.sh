#!/usr/bin/env bash

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
    tput cnorm 2>/dev/null || echo -ne "\033[?25h" >/dev/tty

    local pids=("${BACKGROUND_PIDS[@]}")
    if [[ ${#pids[@]} -gt 0 ]]; then
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
    fi
    printf "\r\033[2K" >/dev/tty
}

trap cleanup EXIT INT TERM

run_silent() {
    local msg="$1"; shift
    local log_file; log_file="$(mktemp)"

    "$@" >"$log_file" 2>&1 &
    local pid=$!
    BACKGROUND_PIDS+=("$pid")

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

detect_environment() {
    log_info "Detectando ambiente e distribuição..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID=$ID
        OS_CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}
    else
        OS_ID=$(uname -s | tr '[:upper:]' '[:lower:]')
        OS_CODENAME=""
    fi

    if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
        IS_WSL=true; log_info "Ambiente WSL detectado."
    else
        IS_WSL=false; log_info "Ambiente Linux nativo detectado."
    fi

    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt-get"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
    else
        log_error "Gerenciador de pacotes não suportado automaticamente."
        exit 1
    fi

    log_info "Distro: ${OS_ID} (${OS_CODENAME}), Gerenciador: ${PKG_MANAGER}"

    export IS_WSL OS_ID OS_CODENAME PKG_MANAGER
}

pkg_install() {
    local msg="$1"; shift
    case "$PKG_MANAGER" in
        apt-get)
            run_silent "$msg" sudo apt-get install -y "$@"
            ;;
        dnf)
            run_silent "$msg" sudo dnf install -y "$@"
            ;;
        pacman)
            run_silent "$msg" sudo pacman -S --noconfirm "$@"
            ;;
        zypper)
            run_silent "$msg" sudo zypper install -y "$@"
            ;;
    esac
}

install_packages() {
    log_info "Instalando pacotes básicos..."

    case "$PKG_MANAGER" in
        apt-get)
            run_silent "Atualizando lista de pacotes" sudo apt-get update -y
            run_silent "Atualizando pacotes instalados" sudo apt-get upgrade -y
            ;;
        dnf)
            run_silent "Atualizando pacotes" sudo dnf upgrade -y
            ;;
    esac

    local packages=(
        curl wget git unzip zip build-essential
        htop tree jq net-tools openssh-client gnupg
    )

    if [[ "$PKG_MANAGER" == "apt-get" && "$OS_ID" == "ubuntu" ]]; then
        packages+=(software-properties-common apt-transport-https ca-certificates lsb-release)
    elif [[ "$PKG_MANAGER" == "apt-get" && "$OS_ID" == "debian" ]]; then
        packages+=(apt-transport-https ca-certificates lsb-release)
    fi

    local to_install=()
    local already=()

    is_installed() {
        case "$PKG_MANAGER" in
            apt-get) dpkg -s "$1" &>/dev/null ;;
            dnf) rpm -q "$1" &>/dev/null ;;
            pacman) pacman -Qs "^$1$" &>/dev/null ;;
            *) command -v "$1" &>/dev/null ;;
        esac
    }

    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        else
            already+=("$pkg")
        fi
    done

    [[ ${#already[@]} -gt 0 ]] && log_warning "Já instalados: ${already[*]}"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        pkg_install "Instalando ${#to_install[@]} pacotes" "${to_install[@]}"
    else
        log_success "Todos os pacotes básicos já estão instalados."
    fi
}

install_zsh() {
    log_info "Configurando ZSH + Oh My Zsh..."

    if ! command -v zsh &>/dev/null; then
        pkg_install "Instalando ZSH" zsh
    else
        log_warning "ZSH já instalado: $(zsh --version)"
    fi

    local zsh_path
    zsh_path="$(command -v zsh)"
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$current_shell" != "$zsh_path" ]]; then
        run_silent "Definindo ZSH como shell padrão" sudo chsh -s "$zsh_path" "$USER"
    else
        log_warning "ZSH já é o shell padrão."
    fi

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        run_silent "Instalando Oh My Zsh" \
            bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    else
        log_warning "Oh My Zsh já instalado."
    fi

    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [[ ! -d "${custom}/plugins/zsh-autosuggestions" ]]; then
        run_silent "Instalando zsh-autosuggestions" \
            git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            "${custom}/plugins/zsh-autosuggestions"
    fi

    if [[ ! -d "${custom}/plugins/zsh-syntax-highlighting" ]]; then
        run_silent "Instalando zsh-syntax-highlighting" \
            git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "${custom}/plugins/zsh-syntax-highlighting"
    fi

    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="duellj"/' "$HOME/.zshrc"
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
    fi

    log_success "ZSH + Oh My Zsh configurados (tema: duellj)."
}

install_node() {
    local version="${NODE_VERSION:-24}"
    log_info "Configurando NVM + Node.js ${version}..."

    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"

    if [[ ! -d "$nvm_dir" ]]; then
        run_silent "Instalando NVM" \
            bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash'
    else
        log_warning "NVM já instalado em: $nvm_dir"
    fi

    local nvm_snippet='
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [[ -f "$rc" ]] && ! grep -q 'NVM_DIR' "$rc" && echo "$nvm_snippet" >> "$rc"
    done

    export NVM_DIR="$nvm_dir"
    set +u
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    set -u

    if command -v nvm &>/dev/null; then
        if nvm ls "$version" &>/dev/null; then
            log_info "Node.js ${version} já está instalado. Definindo como padrão..."
            bash -c "export NVM_DIR=\"$nvm_dir\" && source \"$NVM_DIR/nvm.sh\" && nvm alias default ${version} && nvm use ${version}" >/dev/null
        else
            run_silent "Instalando Node.js ${version}" \
                bash -c "export NVM_DIR=\"$nvm_dir\" && source \"$NVM_DIR/nvm.sh\" && nvm install ${version} && nvm alias default ${version}"
            log_success "Node.js ${version} instalado e definido como padrão."
        fi
    else
        log_warning "NVM não disponível na sessão. Execute: nvm install ${version}"
    fi

    log_success "NVM + Node.js ${version} prontos."
}

install_php() {
    if [[ "$PHP_VERSION" == "skip" ]]; then
        log_info "Instalação do PHP pulada pelo usuário."
        return 0
    fi

    local version="$PHP_VERSION"
    if [[ "$version" == "keep" ]]; then
        version=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
        log_info "Mantendo versão atual do PHP: $version"
    else
        log_info "Configurando PHP ${version}..."

        setup_repo() {
            if [[ "$OS_ID" == "ubuntu" ]]; then
                log_info "Configurando PPA Ondrej para Ubuntu..."
                sudo apt-get update >/dev/null
                sudo apt-get install -y ca-certificates curl gnupg >/dev/null

                local keyring="/usr/share/keyrings/ondrej-php.gpg"
                sudo rm -f "$keyring"
                sudo curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x4F4EA0AAE5267A6C" \
                    | sudo gpg --dearmor -o "$keyring" 2>/dev/null || \
                    sudo gpg --no-default-keyring --keyring "$keyring" --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 4F4EA0AAE5267A6C

                echo "deb [signed-by=${keyring}] https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${OS_CODENAME} main" \
                    | sudo tee /etc/apt/sources.list.d/php.list > /dev/null

            elif [[ "$OS_ID" == "debian" ]]; then
                log_info "Configurando Repositório Sury para Debian..."
                sudo apt-get update >/dev/null
                sudo apt-get install -y lsb-release ca-certificates apt-transport-https curl >/dev/null

                sudo curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
                sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb

                sudo sh -c "echo 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${OS_CODENAME} main' > /etc/apt/sources.list.d/php.list"
            else
                log_warning "Distribuição não suportada automaticamente para repositório PHP customizado: $OS_ID. Tentando pacotes padrão."
                return 0
            fi
            sudo apt-get update -y >/dev/null
        }
        export -f setup_repo
        run_silent "Configurando repositório PHP" setup_repo
    fi

    local php_packages=(
        "php${version}" "php${version}-cli" "php${version}-fpm"
        "php${version}-common" "php${version}-mysql" "php${version}-pgsql"
        "php${version}-sqlite3" "php${version}-curl" "php${version}-mbstring"
        "php${version}-xml" "php${version}-bcmath" "php${version}-zip"
        "php${version}-gd" "php${version}-intl"
        "php${version}-readline" "php${version}-tokenizer" "php${version}-fileinfo"
    )

    pkg_install "Garantindo pacotes PHP ${version} e extensões" \
        bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y ${php_packages[*]}" || return 1

    log_info "Definindo PHP ${version} como padrão do sistema..."
    local binaries=("php" "php-fpm" "phar" "phar.phar" "php-cgi" "php-dbg" "php_dbg")
    for bin in "${binaries[@]}"; do
        if [[ -f "/usr/bin/${bin}${version}" ]]; then
            sudo update-alternatives --set "$bin" "/usr/bin/${bin}${version}" &>/dev/null || true
        fi
    done

    if ! command -v composer &>/dev/null; then
        run_silent "Instalando Composer" \
            bash -c 'curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer'
    fi

    if ! command -v laravel &>/dev/null; then
        export PATH="/usr/local/bin:$PATH"

        run_silent "Instalando Laravel Installer" \
            composer global require laravel/installer --quiet

        local composer_bin; composer_bin=$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")
        local path_snippet="export PATH=\"\$PATH:${composer_bin}\""
        for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
            [[ -f "$rc" ]] && ! grep -q "composer/vendor/bin" "$rc" && echo "$path_snippet" >> "$rc"
        done

        export PATH="$PATH:${composer_bin}"
    fi

    log_success "PHP ${version}, Composer e Laravel Installer prontos"
}

setup_folders() {
    log_info "Configurando estrutura de pastas..."

    local projects_dir="/var/www/projects"

    if [[ ! -d "$projects_dir" ]]; then
        sudo mkdir -p "$projects_dir"
        sudo chown -R "$USER":"$(id -gn)" "$projects_dir"
        log_success "Pasta criada: $projects_dir"
    else
        log_warning "Pasta já existe: $projects_dir"
        sudo chown -R "$USER":"$(id -gn)" "$projects_dir"
    fi

    local symlink="$HOME/projects"

    if [[ -L "$symlink" ]]; then
        log_warning "Symlink já existe: $symlink -> $(readlink "$symlink")"
    elif [[ -d "$symlink" ]]; then
        log_warning "Pasta real em $symlink. Não será sobrescrita."
    else
        ln -s "$projects_dir" "$symlink"
        log_success "Symlink criado: $symlink -> $projects_dir"
    fi

    local target_config_dir=""
    case "${WEB_SERVER:-none}" in
        nginx)  target_config_dir="/etc/nginx/sites-available" ;;
        apache) target_config_dir="/etc/apache2/sites-available" ;;
        *)      log_info "Nenhum servidor web selecionado. Pulando symlink de configs." ; return 0 ;;
    esac

    local configs_symlink="$HOME/configs"
    if [[ -L "$configs_symlink" ]]; then
        log_warning "Symlink de configs já existe: $configs_symlink -> $(readlink "$configs_symlink")"
    elif [[ -d "$configs_symlink" ]]; then
        log_warning "Pasta real em $configs_symlink. Não será sobrescrita."
    else
        ln -s "$target_config_dir" "$configs_symlink"
        log_success "Symlink de configs criado: $configs_symlink -> $target_config_dir"
    fi
}

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

install_docker() {
    log_info "Configurando Docker + Docker Compose..."

    if ! command -v docker &>/dev/null; then
        if [[ "$PKG_MANAGER" == "apt-get" ]]; then
            run_silent "Instalando dependências do Docker" \
                sudo apt-get install -y ca-certificates curl

            run_silent "Adicionando chave GPG do Docker" \
                bash -c "
                    sudo install -m 0755 -d /etc/apt/keyrings
                    sudo curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg \
                        -o /etc/apt/keyrings/docker.asc
                    sudo chmod a+r /etc/apt/keyrings/docker.asc
                "

            run_silent "Adicionando repositório do Docker" \
                bash -c "
                    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
                    https://download.docker.com/linux/${OS_ID} \
                    ${OS_CODENAME} stable\" \
                    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    sudo apt-get update -y
                "

            run_silent "Instalando Docker Engine + Compose plugin" \
                sudo apt-get install -y \
                    docker-ce docker-ce-cli containerd.io \
                    docker-buildx-plugin docker-compose-plugin
        else
            pkg_install "Instalando Docker" docker docker-compose
        fi

        sudo usermod -aG docker "$USER"
        log_success "Docker instalado: $(docker --version)"
    else
        log_warning "Docker já instalado: $(docker --version)"
    fi

    start_docker() {
        if sudo service docker start 2>/dev/null; then return 0; fi
        if sudo /etc/init.d/docker start 2>/dev/null; then return 0; fi
        if sudo systemctl start docker 2>/dev/null; then return 0; fi
        return 1
    }

    if docker info &>/dev/null; then
        log_warning "Docker já está rodando."
    else
        run_silent "Iniciando Docker" start_docker || {
            log_error "Não foi possível iniciar Docker. Pulando containers."
            return 1
        }
    fi

    local db_dir="$HOME/database"
    [[ ! -d "$db_dir" ]] && mkdir -p "$db_dir" && log_info "Pasta ~/database criada."

    local compose_url="https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/docs/docker-compose.yml"
    local compose_dest="$db_dir/docker-compose.yml"

    if [[ ! -f "$compose_dest" ]]; then
        run_silent "Baixando docker-compose.yml" \
            curl -fsSL "$compose_url" -o "$compose_dest"
    else
        log_warning "~/database/docker-compose.yml já existe."
    fi

    if [[ -f "$compose_dest" ]]; then
        log_info "Subindo containers..."
        local services
        services=$(sudo docker compose -f "$compose_dest" config --services 2>/dev/null) || services=""

        for service in $services; do
            local tmp; tmp="$(mktemp)"
            sudo docker compose -f "$compose_dest" up -d "$service" >"$tmp" 2>&1 \
                && log_success "Container iniciado: ${service}" \
                || log_warning "Falha ao subir '${service}'. Verifique: sudo docker compose -f ~/database/docker-compose.yml up -d ${service}"
            rm -f "$tmp"
        done
    fi

    log_success "Docker pronto. Containers em ~/database/"
}

setup_ssh() {
    local key_file="$HOME/.ssh/id_ed25519"

    log_info "Configurando chave SSH para GitHub..."

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$key_file" ]]; then
        log_warning "Chave SSH já existe: $key_file"
    else
        echo -e "\n${CYAN}Digite seu e-mail do GitHub para gerar a chave SSH:${RESET}"
        read -rp "E-mail: " SSH_EMAIL </dev/tty

        if [[ -z "$SSH_EMAIL" ]]; then
            log_warning "E-mail não informado. Pulando configuração SSH."
            return 0
        fi

        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -N "" -f "$key_file" &>/dev/null
        eval "$(ssh-agent -s)" > /dev/null 2>&1
        ssh-add "$key_file" &>/dev/null
        log_success "Chave SSH gerada."
    fi

    local ssh_config="$HOME/.ssh/config"
    if ! grep -q "github.com" "$ssh_config" 2>/dev/null; then
        cat >> "$ssh_config" <<EOF

Host github
  User git
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$ssh_config"
    fi

    echo -e "\n${BOLD}${YELLOW}Chave pública SSH (adicione no GitHub → Settings → SSH Keys):${RESET}"
    echo -e "${CYAN}────────────────────────────────────────${RESET}"
    cat "${key_file}.pub"
    echo -e "${CYAN}────────────────────────────────────────${RESET}\n"
}

echo -e "${CYAN}${BOLD}"
cat << "EOF"
    ____               __  __           _     _                _____      _
   |  _ \  _____   __/  \/  | __ _  ___| |__ (_)_ __   ___    / ____| ___| |_ _   _ _ __
   | | | |/ _ \ \ / /| \  / |/ _` |/ __| '_ \| | '_ \ / _ \   \___ \ / _ \ __| | | | '_ \
   | |_| |  __/\ V / | |\/| | (_| | (__| | | | | | | |  __/    ___) |  __/ |_| |_| | |_) |
   |____/ \___| \_/  |_|  |_|\__,_|\___|_| |_|_|_| |_|\___|   |____/ \___|\__|\__,_| .__/
                                                                                   |_|
EOF
echo -e "${RESET}"

detect_environment

echo -e "${BOLD}${YELLOW}Insira sua senha sudo (pedida apenas uma vez):${RESET}"
sudo -v

( while kill -0 "$$" 2>/dev/null; do sudo -n -v 2>/dev/null; sleep 30; done ) &
SUDO_KEEPALIVE_PID=$!
BACKGROUND_PIDS+=("$SUDO_KEEPALIVE_PID")

if [[ "$OS_ID" == "ubuntu" ]]; then
    OS_VERSION_MAJOR=$(echo "$VERSION_ID" | cut -d. -f1)
    if [[ "$OS_VERSION_MAJOR" -lt 22 ]]; then
        echo -e "\n${BOLD}${YELLOW}![AVISO]${RESET} Você está no Ubuntu ${VERSION_ID}."
        echo -e "${YELLOW}Versões abaixo do 22.04 podem ter instabilidades com PHP 8.4+.${RESET}"
        echo -e "${YELLOW}Recomendamos PHP 8.3 ou upgrade da distro para melhor performance.${RESET}\n"
    fi
fi

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

CURRENT_PHP_VERSION=""
if command -v php &>/dev/null; then
    CURRENT_PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    log_info "PHP $CURRENT_PHP_VERSION detectado no sistema."
fi

PHP_OPTIONS=()
[[ -n "$CURRENT_PHP_VERSION" ]] && PHP_OPTIONS+=("Manter versão atual ($CURRENT_PHP_VERSION)")
PHP_OPTIONS+=("PHP 8.5 (experimental/PPA)" "PHP 8.4 (estável)" "PHP 8.3 (recomendado)" "Pular instalação do PHP")

select_arrow "Qual versão do PHP instalar?" "${PHP_OPTIONS[@]}"

if [[ -n "$CURRENT_PHP_VERSION" ]]; then
    case $ARROW_REPLY in
        0) PHP_VERSION="keep" ;;
        1) PHP_VERSION="8.5" ;;
        2) PHP_VERSION="8.4" ;;
        3) PHP_VERSION="8.3" ;;
        4) PHP_VERSION="skip" ;;
    esac
else
    case $ARROW_REPLY in
        0) PHP_VERSION="8.5" ;;
        1) PHP_VERSION="8.4" ;;
        2) PHP_VERSION="8.3" ;;
        3) PHP_VERSION="skip" ;;
    esac
fi
export PHP_VERSION

select_arrow "Qual versão do Node.js instalar?" \
    "Node 25" \
    "Node 24  (LTS atual - recomendado)" \
    "Node 23" \
    "Node 22  (LTS ativo)" \
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

kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

echo -e "${GREEN}${BOLD}"
cat << "EOF"
    _____ ______ _______ _    _ _____     _____ ____  __  __ _____  _      ______ _______ ______
   / ____|  ____|__   __| |  | |  __ \   / ____/ __ \|  \/  |  __ \| |    |  ____|__   __|  ____|
  | (___ | |__     | |  | |  | | |__) | | |   | |  | | \  / | |__) | |    | |__     | |  | |__
   \___ \|  __|    | |  | |  | |  ___/  | |   | |  | | |\/| |  ___/| |    |  __|    | |  |  __|
   ____) | |____   | |  | |__| | |      | |___| |__| | |  | | |    | |____| |____   | |  | |____
  |_____/|______|  |_|   \____/|_|       \_____\____/|_|  |_|_|    |______|______|  |_|  |______|

EOF
echo -e "${RESET}"
echo -e ""
echo -e "  • Projetos: ${BOLD}/var/www/projects${RESET}  →  ~/projects"
echo -e "  • Docker:   ${BOLD}~/database/docker-compose.yml${RESET}"
echo -e "  • Containers: MySQL · MinIO · Mailpit"
echo -e ""
echo -e "${YELLOW}Entrando no ZSH...${RESET}\n"

exec zsh
