## Instalação Automática 

O script configura pacotes, ZSH, Node.js, PHP, Nginx/Apache, Docker e estrutura de pastas.

### Ubuntu / WSL

```bash
bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/dev-machine-setup/setup.sh)
```

### Debian (ou sistemas minimalistas)

```bash
sudo apt-get update && sudo apt-get install -y curl && bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/dev-machine-setup/setup.sh)
```

## O que é instalado

| Componente      | Detalhes                                      |
| --------------- | --------------------------------------------- |
| Pacotes básicos | curl, git, wget, unzip, build-essential, etc. |
| ZSH             | + Oh My Zsh + autosuggestions + highlighting  |
| Node.js         | Via NVM, versão LTS mais recente              |
| PHP             | Versão configurável (8.3, 8.4, etc.)          |
| Composer        | Via instalador oficial                        |
| Servidor web    | Nginx (padrão) ou Apache                      |
| Docker          | Engine + Compose Plugin                       |


---

## Instalação Manual e Detalhes

Se preferir configurar manualmente cada componente:

### Terminal e ZSH

[Configuração do ZSH](Terminal-ZSH/zsh.md)

### Node.js (Manual)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
nvm install 24
```

### PHP 8+ (Manual)

```bash
sudo apt-get update && sudo apt install php php-xml php-curl php-mbstring php-pgsql php-mysql php-zip
```

### Composer (Manual)

```bash
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
```

### Docker (Manual)

[Guia do Docker](Docker/install.md)

### SSH e Git

[Configurar SSH](SSH/ssh.md)

### Projetos e Deploys

- [Configuração de Projeto](ConfigProject/install.md)
- [Certificado SSL](Deploy/certificado_ssl.md)
- [Nginx HTTP/HTTPS](Deploy/nginx-HTTP.md)
