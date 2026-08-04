[Voltar](../README.md)

# Instação e configuração do zsh no linux

### Instalar e configurar ZSH

```bash
sudo apt update -y && sudo apt upgrade -y 
```

```bash
sudo apt install zsh -y
```

```bash
chsh -s /bin/zsh
```

```bash
zsh
```
### Instalar Oh-my-zsh

```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
### Instalar Spaceship Prompt + Autosuggestions + Syntax Highlighting

```bash
Z="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}" &&
git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git "$Z/themes/spaceship-prompt" &&
ln -s "$Z/themes/spaceship-prompt/spaceship.zsh-theme" "$Z/themes/spaceship.zsh-theme" &&
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$Z/plugins/zsh-autosuggestions" &&
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$Z/plugins/zsh-syntax-highlighting"
```
### Configurar o bash Shell

```bash
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="duellj"/' ~/.zshrc
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
```
```bash
zsh
```

- Old config
```bash
nano ~/.zshrc
ZSH_THEME="duellj"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```
