# deploy

Scripts para provisionar um servidor Ubuntu e fazer deploy zero-downtime de projetos Laravel (releases datadas + symlink `current`).

## Uso

```bash
# 1. baixa e roda tudo: provisiona o servidor (pergunta sim/não por item: PHP+Composer,
#    Node, nginx, pnpm — responda N em tudo para pular) e em seguida cria a estrutura do
#    projeto e gera o script de deploy dele (pergunta: nome, repo SSH, branch, binário do PHP)
bash <(curl -s https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/main/scripts/deploy/setup.sh)

# 2. a cada release (gerado no diretório onde você rodou o passo 1)
./deploy-<projeto>.sh
```

Com o repositório clonado, `./setup.sh` funciona igual (usa o `deploy.template.sh` local).

## Como funciona

- `setup.sh` — roda 1x por projeto. Primeiro provisiona o servidor: instala PHP + Composer (versão disponível no apt do sistema), Node (nodesource), nginx e pnpm (corepack), com spinner de progresso — cada item é opcional e idempotente (pula o que já existe; funciona como root ou com sudo). Depois cria `/var/www/projects/<projeto>/{releases,shared/storage/...}` com permissões (`www-data`, setgid 2775), gera deploy key se faltar e monta o `deploy-<projeto>.sh` a partir do `deploy.template.sh` (placeholders `{{PROJECT}}`, `{{REPOSITORY}}`, `{{BRANCH}}`, `{{PHP_BINARY}}`).
- `deploy.template.sh` — molde do deploy (não roda direto): clone raso datado, `.env` base do `.env.example` no 1º deploy (com `key:generate`), symlinks pro `shared/`, `composer install --no-dev`, assets por lockfile (`pnpm-lock.yaml` → pnpm, senão `npm ci`), `migrate --force` + `artisan optimize`, troca atômica do `current` e limpeza mantendo as 3 releases mais novas.

## Notas

- Projeto com pnpm: fixe `"packageManager": "pnpm@10.12.1"` no `package.json` — sem isso o corepack baixa o pnpm mais novo, que pode exigir Node mais novo que o do servidor.
- No pnpm o `node_modules` fica na release (é link pro store, custa ~zero disco e cobre runtime Node como SSR); no npm ele é removido após o build.
- Mudou a lógica de deploy? Edite o `deploy.template.sh` e regere os scripts dos projetos.
