[Voltar](../README.md)

# SSH

## Linux local — chave para o GitHub (ed25519)

Gera a chave, sobe o agent e adiciona a chave nele:

```bash
echo -n "Email do Git: "
read SSH_EMAIL
ssh-keygen -t ed25519 -C "$SSH_EMAIL" -N "" -f "$HOME/.ssh/id_ed25519" && eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

Pegue a chave pública e cadastre no GitHub (Settings → SSH Keys):

```bash
cat ~/.ssh/id_ed25519.pub
```

Depois de cadastrar, configure o host e teste a conexão:

```bash
echo -e "Host github\n  User git\n  HostName github.com\n  IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
ssh -T git@github.com
```

## Linux servidor — chave de acesso (rsa 4096)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/nome_da_chave && eval "$(ssh-agent -s)" && ssh-add ~/.ssh/nome_da_chave
```

Sem o nome do usuário do pc no comentário da chave:

```bash
ssh-keygen -t rsa -b 4096 -C "" -f "$HOME/.ssh/nome_da_chave" && eval "$(ssh-agent -s)" && ssh-add "$HOME/.ssh/nome_da_chave"
```

Configure o host do servidor e conecte:

```bash
echo -e "Host nomeDoServidor\n  HostName 100.100.100.100\n  IdentityFile ~/.ssh/nome_da_chave" >> ~/.ssh/config
ssh nomeDoServidor
```

## Windows (PowerShell)

```powershell
ssh-keygen -t rsa -b 4096 -f "C:\Users\$env:USERNAME\.ssh\nome_da_chave"
```

Sem o nome do usuário do pc no comentário da chave:

```powershell
ssh-keygen -t rsa -b 4096 -C "" -f "C:\Users\$env:USERNAME\.ssh\nome_da_chave"
```
