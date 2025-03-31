#!/bin/bash

has_sudo() {
    if sudo -l &>/dev/null; then
        return 0
    else
        return 1
    fi
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

    # More programs
    sudo apt install -y neovim ranger tmux duf procs sd
else
    echo "No sudo pivileges, skipping package installation."
fi

if ! command -v zsh &> /dev/null; then
    echo "Error: Zsh is not installed. Please install it first."
    exit 1
fi

# Clone the config repo if it doesn't already exist
if [ ! -d "$HOME/.config/zsh" ]; then
    git clone --recurse-submodules --shallow-submodules https://github.com/Ninteedo/dotfiles.git "$HOME/.config/zsh"
else
    echo "Configuration repository already exists. Skipping clone."
fi

# Set Zsh as default shell
# chsh -s $(which zsh)

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed, skipping."
fi

echo "Linking configuration files"

if [ ! -f ~/.zshrc ]; then
    echo "Creating a minimal ~/.zshrc to source custom configuration"
    echo "source ~/.config/zsh/.zshrc" > ~/.zshrc
elif ! grep -q "source ~/.config/zsh/.zshrc" ~/.zshrc; then
    echo "Adding source command to ~/.zshrc"
    echo "source ~/.config/zsh/.zshrc" >> ~/.zshrc
else
    echo "~/.zshrc already correctly configured."
fi

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

# Test if Zsh is configured properly
if zsh -c "echo Zsh is working!" &> /dev/null; then
    echo "Zsh environment setup complete!"
else
    echo "Error: Zsh configuration failed. Please check your .zshrc."
fi

echo "Setup complete! Run 'zsh' to start using your new shell."
