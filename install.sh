#!/bin/bash

has_sudo() {
    sudo -n true 2>/dev/null
    return $?
}

if [ "$(id -u)" = "0" ]; then
    echo "Error: Do not run this script as root."
    exit 1
fi

# Install Zsh and Git if not installed
if has_sudo; then
    echo "Sudo privileges detected, installing packages..."
    sudo apt update
    sudo apt install -y zsh git curl
else
    echo "No sudo pivileges, skipping package installation."
fi

if ! command -v zsh &> /dev/null; then
    echo "Error: Zsh is not installed. Please install it first."
    exit 1
fi

# Set Zsh as default shell (check if it's already set)
if [ "$SHELL" != "$(which zsh)" ]; then
    if has_sudo; then
        echo "Setting Zsh as default shell for $USER..."
        sudo chsh -s "$(which zsh)" "$USER"
    else
        echo "Cannot change default shell without sudo privileges."
    fi
else
    echo "Zsh is already the default shell."
fi

# Clone the config repo if it doesn't already exist
if [ ! -d "$HOME/.config/zsh" ]; then
    git clone --recurse-submodules --shallow-submodules https://github.com/Ninteedo/dotfiles.git "$HOME/.config/zsh"
else
    echo "Configuration repository already exists. Skipping clone."
fi

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

# Check if the .zshrc has been sourced correctly
if grep -q "source ~/.zshrc" ~/.zshrc; then
    echo ".zshrc already sourced."
else
    echo "source ~/.zshrc" >> ~/.zshrc
fi

# Test if Zsh is configured properly
if zsh -c "echo Zsh is working!" &> /dev/null; then
    echo "Zsh environment setup complete!"
else
    echo "Error: Zsh configuration failed. Please check your .zshrc."
fi

echo "Setup complete! Run 'zsh' to start using your new shell."
