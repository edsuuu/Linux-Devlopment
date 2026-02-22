## Terminal com auto-complete

Instalação automatica

## Ubuntu 

```bash
bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/dev-machine-setup/setup.sh)
```

### Debian

```bash
sudo apt-get update && sudo apt-get install -y curl && bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/dev-machine-setup/setup.sh)
```



[TERMINAL_ZSH](Terminal-ZSH/zsh.md)

## NodeJs

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

```bash
\. "$HOME/.nvm/nvm.sh"
```

```bash
nvm install 24 && node -v && npm -v 
```

## PHP 8+

```bash
sudo apt-get update && sudo apt install php php-xml php-curl php-mbstring php-pgsql php-mysql php-zip
```

### Composer

```bash
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer
```

## Docker, Banco de dados e APPS Email e S3

[Docker](Docker/install.md)

## SSH GIT

[SSH](SSH/ssh.md)

## Configurando projeto
[SSH](ConfigProject/install.md)

# Deploys config 
[CERTIFICADO SSL](Deploy/certificado_ssl.md)

## (Nginx)

[NGINX HTTP NODEJS](Deploy/nginx-HTTP.md)

[NGINX HTTPS NODEJS](Deploy/nginx-HTTPS.md)

### Instalação do NGINX

```bash
sudo apt install nginx -y && sudo systemctl start nginx

sudo systemctl status nginx

```

```bash
sudo systemctl status nginx

cd /etc/nginx/sites-enabled/ 

sudo rm -rf default

sudo nano seudominio.com.br

sudo nginx -t && sudo systemctl restart nginx 

```
## (Apache)