#!/bin/bash

DOTFILES_DIR=$(dirname "$(realpath "$0")")
ZSH_DIR="$DOTFILES_DIR/zsh"
CUSTOM_DIR="$ZSH_DIR/custom"

has_sudo() {
    sudo -l &>/dev/null
}

if [ "$(id -u)" = "0" ]; then
    echo "Error: Do not run this script as root."
    exit 1
fi

# Install packages
if has_sudo; then
    echo "Sudo privileges detected, installing packages..."
    sudo apt update
    sudo apt install -y zsh git curl neovim ranger tmux duf sd
else
    echo "No sudo pivileges, skipping package installation."
fi

if ! command -v zsh &> /dev/null; then
    echo "Error: Zsh is not installed. Please install it first."
    exit 1
fi

# zshrc link
ln -sf "$ZSH_DIR/.zshrc" "$HOME/.zshrc"
# Powerlevel10k link
ln -sf "$ZSH_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

# Oh My Zsh
if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    echo "Installing Oh My Zsh..."
    rm -rf "$HOME/.oh-my-zsh"
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(wget -O - https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed."
fi

# Link themes and plugins
mkdir -p "$HOME/.oh-my-zsh/custom/themes" "$HOME/.oh-my-zsh/custom/plugins"
for theme in "$CUSTOM_DIR/themes/"*; do
    [ -e "$theme" ] && ln -sf "$theme" "$HOME/.oh-my-zsh/custom/themes/"
done
for plugin in "$CUSTOM_DIR/plugins/"*; do
    [ -e "$plugin" ] && ln -sf "$plugin" "$HOME/.oh-my-zsh/custom/plugins/"
done

# Test Zsh
if zsh -c "echo Zsh is working" &>/dev/null; then
    echo "Zsh environment setup complete."
else
    echo "Error: Zsh configuration failed. Check your dotfiles."
    exit 1
fi

# Install Neovim setup
bash "$DOTFILES_DIR/setup_neovim.sh" "$DOTFILES_DIR/init.vim"

# Locale setup (only if sudo)
if has_sudo; then
    echo "Enabling en_GB.UTF-8 locale..."
    sudo sed -i 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen
    sudo update-locale LANG=en_GB.UTF-8
    export LANG=en_GB.UTF-8
    export LC_ALL=en_GB.UTF-8
fi

# git setup
git config --global core.editor "vim"

# Link bin folder
if [ ! -d "$HOME/bin" ] || [ -z "$(ls -A "$HOME/bin" 2>/dev/null)" ]; then
    echo "Linking ~/bin -> $DOTFILES_DIR/zsh/bin"
    ln -sfn "$DOTFILES_DIR/bin" "$HOME/bin"
fi

echo "Install complete."

