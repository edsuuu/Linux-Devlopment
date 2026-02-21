# dev-machine-setup

> Automação completa de ambiente de desenvolvimento para WSL/Ubuntu.

## 🚀 Uso rápido

```bash
bash <(curl -s https://raw.githubusercontent.com/meuuser/dev-machine-setup/main/setup.sh)
```

## O que é instalado

| Componente      | Detalhes                                      |
| --------------- | --------------------------------------------- |
| Pacotes básicos | curl, git, wget, unzip, build-essential, etc. |
| ZSH             | + Oh My Zsh + autosuggestions + highlighting  |
| Node.js         | Via NVM, versão LTS mais recente              |
| PHP             | Versão configurável (padrão: 8.3)             |
| Composer        | Via instalador oficial                        |
| Laravel         | Installer global via Composer                 |
| Servidor web    | Nginx (padrão) ou Apache (à sua escolha)      |
| Docker          | Via script oficial get.docker.com             |
| Docker Compose  | Plugin oficial                                |

## Containers Docker incluídos

| Container | Porta(s)    | Descrição                      |
| --------- | ----------- | ------------------------------ |
| MySQL 8   | 3306        | Banco de dados relacional      |
| Redis     | 6379        | Cache / filas                  |
| MailHog   | 1025 / 8025 | Captura de e-mails (SMTP + UI) |
| MinIO     | 9000 / 9001 | Storage S3-compatible          |

## Estrutura de pastas criada

```
/var/www/projects    ← pasta principal de projetos
~/projects           ← symlink para /var/www/projects
~/docker/            ← pasta do Docker Compose
```

## Estrutura do projeto

```
dev-machine-setup/
├── setup.sh                  # Entry point principal
├── lib/
│   ├── packages.sh           # Pacotes básicos
│   ├── zsh.sh                # ZSH + Oh My Zsh
│   ├── node.sh               # NVM + Node LTS
│   ├── php.sh                # PHP + Composer + Laravel
│   ├── nginx.sh              # Nginx ou Apache
│   ├── docker.sh             # Docker + Compose
│   └── folders.sh            # /var/www/projects + symlink
└── docker/
    └── docker-compose.yml    # MySQL, Redis, MailHog, MinIO
```

## Características

- ✅ **Idempotente** — pode ser executado várias vezes sem quebrar
- ✅ **Modular** — cada ferramenta é um módulo independente
- ✅ **Logs coloridos** — INFO, SUCCESS, WARNING
- ✅ **Detecção de WSL** — comportamento adaptado ao ambiente
- ✅ **Fontes oficiais** — Docker, NVM, Composer via sites oficiais
- ✅ **Versão de PHP configurável** — sem precisar editar o script

## Variáveis de ambiente disponíveis

```bash
PHP_VERSION=8.2 bash <(curl -s https://raw.githubusercontent.com/meuuser/dev-machine-setup/main/setup.sh)
```

| Variável    | Padrão | Descrição                     |
| ----------- | ------ | ----------------------------- |
| PHP_VERSION | 8.3    | Versão do PHP a instalar      |
| WEB_SERVER  | nginx  | `nginx`, `apache` ou `none`   |
| BASE_URL    | GitHub | URL base para módulos remotos |

## Pós-instalação

Após a execução, reinicie o terminal ou execute:

```bash
source ~/.zshrc
```

## Licença

MIT
