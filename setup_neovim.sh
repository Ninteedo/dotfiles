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

# Create a temporary directory for the build
BUILD_DIR=$(mktemp -d)
echo "Cloning Neovim into $BUILD_DIR"

# Download Neovim release to a writable location
pushd "$BUILD_DIR"
wget https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-x86_64.tar.gz

# Extract and move to the appropriate location
tar -xzf nvim-linux-x86_64.tar.gz

# Move the entire Neovim directory to a local bin folder
mkdir -p ~/.local/neovim
rm -rf ~/.local/neovim/nvim-linux-x86_64
mv nvim-linux-x86_64 ~/.local/neovim

mkdir -p "$HOME/.local/neovim/bin"
ln -sf "$HOME/.local/neovim/nvim-linux-x86_64/bin/nvim" "$HOME/.local/neovim/bin/nvim"
ln -sf "$HOME/.local/neovim/nvim-linux-x86_64/bin/nvim" "$HOME/.local/neovim/bin/vim"

# Clean up
popd
rm -rf "$BUILD_DIR"

echo "Neovim installed locally, installing vim-plug."

# Install vim-plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Link config
ln -sf "$INIT_VIM_PATH" ~/.config/nvim/init.vim

nvim --headless +PlugInstall +qall

echo "vim-plug installation complete. Please restart your terminal to use Neovim."

