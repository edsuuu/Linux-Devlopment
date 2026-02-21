#!/usr/bin/env bash
# =============================================================================
# lib/folders.sh - Criação de pastas e symlinks
# =============================================================================

setup_folders() {
    log_info "Configurando estrutura de pastas..."

    # -------------------------------------------------------------------------
    # /var/www/projects
    # -------------------------------------------------------------------------
    local projects_dir="/var/www/projects"

    if [[ ! -d "$projects_dir" ]]; then
        sudo mkdir -p "$projects_dir"
        sudo chown -R "$USER":"$(id -gn)" "$projects_dir"
        log_success "Pasta criada: $projects_dir"
    else
        log_warning "Pasta já existe: $projects_dir"
        # Garante permissão correta mesmo que já exista
        sudo chown -R "$USER":"$(id -gn)" "$projects_dir"
    fi

    # -------------------------------------------------------------------------
    # Symlink ~/projects -> /var/www/projects
    # -------------------------------------------------------------------------
    local symlink="$HOME/projects"

    if [[ -L "$symlink" ]]; then
        log_warning "Symlink já existe: $symlink -> $(readlink "$symlink")"
    elif [[ -d "$symlink" ]]; then
        log_warning "Existe uma pasta real em $symlink. Não será sobrescrita."
    else
        ln -s "$projects_dir" "$symlink"
        log_success "Symlink criado: $symlink -> $projects_dir"
    fi

    log_success "Estrutura de pastas configurada."
}
