#!/bin/bash

# Install Zsh and Git if not installed
sudo apt update
sudo apt install -y zsh git curl

# Clone the config repo
git clone --recurse-submodules https://github.com/Ninteedo/dotfiles.git ~/.config/zsh

# Link configs
ln -sf ~/.config/zsh/.zshrc ~/.zshrc
ln -sf ~/.config/zsh/.p10k.zsh ~/.p10k.zsh

# Set Zsh as default shell
chsh -s $(which zsh)

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Source the new configuration
source ~/.zshrc

echo "Zsh environment setup complete!"
