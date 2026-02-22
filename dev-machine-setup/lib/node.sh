#!/usr/bin/env bash

install_node() {
    local version="${NODE_VERSION:-22}"
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
            log_info "Node.js ${version} já está instalado via NVM."
        else
            run_silent "Instalando Node.js ${version}" \
                bash -c "export NVM_DIR=\"$nvm_dir\" && source \"$NVM_DIR/nvm.sh\" && nvm install ${version} && nvm alias default ${version}"
            log_success "Node.js ${version} instalado com sucesso."
        fi
    else
        log_warning "NVM não disponível na sessão. Execute: nvm install ${version}"
    fi

    log_success "NVM + Node.js ${version} prontos."
}
