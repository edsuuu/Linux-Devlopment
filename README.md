Documentação navegável: **https://edsuuu.github.io/Linux-Devlopment/**

## Instalação Automática 

O script configura pacotes, ZSH, Node.js, PHP, Nginx/Apache, Docker e estrutura de pastas.

### Ubuntu / WSL

```bash
bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/scripts/dev-machine-setup/setup.sh)
```

### Debian (ou sistemas minimalistas)

```bash
sudo apt-get update && sudo apt-get install -y curl && bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/scripts/dev-machine-setup/setup.sh)
```

## Servidor de Deploy (Laravel)

Provisiona o servidor (PHP, Node, nginx, pnpm), cria a estrutura do projeto e gera o script de deploy zero-downtime — tudo em uma linha:

```bash
bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/scripts/deploy/setup.sh)
```
