#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./setup_neovim.sh <init.vim>"
    exit 1
fi

# Resolve the absolute path of the init.vim file
INIT_VIM_PATH=$(realpath "$1")

# Link config
mkdir -p ~/.config/nvim
ln -sf "$INIT_VIM_PATH" ~/.config/nvim/init.vim
sudo apt remove -y neovim

# Create a temporary directory for the build
BUILD_DIR=$(mktemp -d)
echo "Cloning Neovim into $BUILD_DIR"

# Download Neovim release to a writable location
pushd "$BUILD_DIR"
wget https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-x86_64.tar.gz

# Extract and move to the appropriate location
tar -xzf nvim-linux-x86_64.tar.gz

# Move the entire Neovim directory to /usr/local
sudo rm -rf /usr/local/nvim
sudo mv nvim-linux-x86_64 /usr/local/nvim

# Create a symlinks for commands
sudo ln -sf /usr/local/nvim/bin/nvim /usr/local/bin/nvim
sudo update-alternatives --install /usr/bin/vim vim /usr/local/bin/nvim 100
sudo update-alternatives --set vim /usr/local/bin/nvim

# sudo rm -f /usr/bin/vim
# sudo ln -sf /usr/local/bin/nvim /usr/bin/vim

# Clean up
popd
rm -rf "$BUILD_DIR"

echo "Neovim installed, installing vim-plug."

# Install vim-plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Link config
ln -sf "$INIT_VIM_PATH" ~/.config/nvim/init.vim

nvim --headless +PlugInstall +qall

echo "vim-plug installion complete."

