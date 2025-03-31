#!/bin/bash

# Variables
REPO_URL="https://github.com/Ninteedo/dotfiles.git"
CLONE_DIR="$HOME/.config/zsh"

echo "Cloning repository from $REPO_URL..."
# Clone the repository (shallow)
git clone --depth 1 --recurse-submodules $REPO_URL $CLONE_DIR

# Check if the clone was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to clone the repository."
    exit 1
fi

echo "Running install script..."
# Change to the cloned directory and execute the install script
bash $CLONE_DIR/install.sh

echo "Setup complete!"

