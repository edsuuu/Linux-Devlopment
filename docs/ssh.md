[Voltar](../README.md)

## SSH GIT

```bash
echo -n "Email do Git: "
read SSH_EMAIL
ssh-keygen -t ed25519 -C "$SSH_EMAIL" -N "" -f "$HOME/.ssh/id_ed25519" && eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

- Pegue a chave e configure no git
```bash
cat ~/.ssh/id_ed25519.pub
```

- Depois de configurar no git

```bash
echo -e "Host github\n  User git\n  HostName github.com\n  IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
```


## Geração das chave SSH
- Windows 
```bash
ssh-keygen -f "C:\Users\$env:USERNAME\.ssh\nomedachavessh" -t rsa -b 4096
```
```bash
ssh-keygen -t rsa -b 4096 -C "" -f "C:\Users\$env:USERNAME\.ssh\nomedachavessh"
```
- Linux 
```bash
ssh-keygen -f ~/.ssh/nome_da_chave -t rsa -b 4096
```
- Sem nome do usuario do pc
```bash
ssh-keygen -t rsa -b 4096 -C "" -f "$HOME/.ssh/nomedachavessh" 
```
```bash
echo "Host nomeDoServidor
    HostName 100.100.100.100
    IdentityFile id_rsa" >> config

```

```bash
ssh -T git@github.com

```

