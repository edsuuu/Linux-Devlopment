#!/usr/bin/env bash

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
}
