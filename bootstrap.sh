#!/bin/bash

# Variables
REPO_URL="https://github.com/Ninteedo/dotfiles.git"
CLONE_DIR="$HOME/.config/zsh"

if [ "$(id -u)" = "0" ]; then
    echo "Error: Do not run this script as root."
    exit 1
fi

# Clone the repository (shallow), prompt to overwrite if exists
echo "Cloning repository from $REPO_URL..."
if [ -d "$CLONE_DIR" ]; then
    echo "Directory $CLONE_DIR already exists."
    read -p "Overwrite existing configuration? (y/N) " choice
    if [[ "$choice" != [yY] ]]; then
        echo "Aborting setup."
        exit 1
    fi
    rm -rf "$CLONE_DIR"
fi

# Clone the repository
git clone --depth 1 --recurse-submodules --shallow-submodules $REPO_URL $CLONE_DIR

# Check if the clone was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to clone the repository."
    exit 1
fi

echo "Running install script..."
# Change to the cloned directory and execute the install script
bash $CLONE_DIR/install.sh

echo "Setup complete!"

