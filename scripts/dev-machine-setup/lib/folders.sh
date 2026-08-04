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
