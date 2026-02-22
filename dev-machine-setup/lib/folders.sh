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

    # Pasta de Configurações do Servidor Web
    local configs_dir="/var/www/configs"
    if [[ ! -d "$configs_dir" ]]; then
        sudo mkdir -p "$configs_dir"
        sudo chown -R "$USER":"$(id -gn)" "$configs_dir"
        log_success "Pasta de configurações criada: $configs_dir"
    else
        log_warning "Pasta de configurações já existe: $configs_dir"
        sudo chown -R "$USER":"$(id -gn)" "$configs_dir"
    fi

    local configs_symlink="$HOME/configs"
    if [[ -L "$configs_symlink" ]]; then
        log_warning "Symlink de configs já existe: $configs_symlink -> $(readlink "$configs_symlink")"
    elif [[ -d "$configs_symlink" ]]; then
        log_warning "Pasta real em $configs_symlink. Não será sobrescrita."
    else
        ln -s "$configs_dir" "$configs_symlink"
        log_success "Symlink de configs criado: $configs_symlink -> $configs_dir"
    fi
}
