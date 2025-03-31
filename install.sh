#!/bin/bash

has_sudo() {
    sudo -n true 2>/dev/null
    return $?
}

# Install Zsh and Git if not installed
if has_sudo; then
    echo "Sudo privileges detected, installing packages..."
    sudo apt update
    sudo apt install -y zsh git curl
else
    echo "No sudo pivileges, skipping package installation."
fi

# Clone the config repo
git clone --recurse-submodules --shallow-submodules https://github.com/Ninteedo/dotfiles.git ~/.config/zsh

# Set Zsh as default shell
chsh -s $(which zsh)

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed, skipping."
fi

echo "Linking configuration files"
ln -sf ~/.config/zsh/.zshrc ~/.zshrc
ln -sf ~/.config/zsh/.p10k.zsh ~/.p10k.zsh

mkdir -p ~/.oh-my-zsh/custom/themes
mkdir -p ~/.oh-my-zsh/custom/plugins

# Link themes and plugins, avoiding duplicates
echo "Linking themes and plugins..."
for theme in ~/.config/zsh/custom/themes/*; do
    ln -sf "$theme" ~/.oh-my-zsh/custom/themes/
done

for plugin in ~/.config/zsh/custom/plugins/*; do
    ln -sf "$plugin" ~/.oh-my-zsh/custom/plugins/
done


# Source the new configuration
source ~/.zshrc

echo "Zsh environment setup complete!"
