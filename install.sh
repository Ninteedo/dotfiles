#!/bin/bash

DOTFILES_DIR=$(dirname "$(realpath "$0")")
ZSH_DIR="$DOTFILES_DIR/zsh"
CUSTOM_DIR="$ZSH_DIR/custom"

has_sudo() {
    command -v sudo &>/dev/null && sudo -l &>/dev/null
}

if [ "$(id -u)" = "0" ]; then
    echo "Error: Do not run this script as root."
    exit 1
fi

# Detect package manager (covers Debian/Ubuntu/Mint, Arch/Manjaro, Fedora/Nobara etc.)
if command -v apt-get &>/dev/null; then
    PM=apt
elif command -v pacman &>/dev/null; then
    PM=pacman
elif command -v dnf &>/dev/null; then
    PM=dnf
else
    PM=unknown
fi

pkg_install() {
    case "$PM" in
        apt)    sudo apt-get install -y "$@" ;;
        # No -y refresh (-Sy) on purpose: partial upgrades are unsupported on Arch.
        # If this fails with 404s, run 'sudo pacman -Syu' first.
        pacman) sudo pacman -S --needed --noconfirm "$@" ;;
        dnf)    sudo dnf install -y "$@" ;;
    esac
}

# Install packages
if [ "$PM" = "unknown" ]; then
    echo "No supported package manager found (apt, pacman, dnf), skipping package installation."
elif has_sudo; then
    echo "Sudo privileges detected, installing packages with $PM..."
    [ "$PM" = "apt" ] && sudo apt-get update

    # Core packages: a failure here should be visible
    pkg_install zsh git curl neovim \
        || echo "Warning: some core packages failed to install."

    # Optional packages: not available in every release, so install one by one
    for pkg in duf sd ripgrep btop fzf ranger tmux bat eza lazygit; do
        pkg_install "$pkg" || echo "Note: '$pkg' is not available on this system, skipping."
    done

    case "$PM" in
        apt)
            # install eza
            pkg_install gpg
            sudo mkdir -p /etc/apt/keyrings
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
            sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
            sudo apt update
            sudo apt install -y eza
            ;;
        pacman)
            ;;
        dnf)
            sudo dnf -y copr enable dejan/lazygit
            sudo dnf -y install lazygit
            ;;
        *)
            ;;
    esac

else
    echo "No sudo privileges, skipping package installation."
fi

if ! command -v zsh &>/dev/null; then
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
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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

# zoxide
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Locale setup (only if sudo)
setup_locale() {
    local loc="en_GB.UTF-8"
    case "$PM" in
        apt)
            pkg_install locales
            sudo sed -i "s/^#\s*en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/" /etc/locale.gen
            sudo locale-gen
            sudo update-locale LANG="$loc"
            ;;
        pacman)
            sudo sed -i "s/^#\s*en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/" /etc/locale.gen
            sudo locale-gen
            echo "LANG=$loc" | sudo tee /etc/locale.conf >/dev/null
            ;;
        dnf)
            # Fedora ships locales as langpacks rather than generating them
            pkg_install glibc-langpack-en
            sudo localectl set-locale LANG="$loc" 2>/dev/null \
                || echo "LANG=$loc" | sudo tee /etc/locale.conf >/dev/null
            ;;
        *)
            return 1
            ;;
    esac
    export LANG="$loc"
    export LC_ALL="$loc"
}

if [ "$PM" != "unknown" ] && has_sudo; then
    echo "Enabling en_GB.UTF-8 locale..."
    setup_locale || echo "Warning: locale setup failed."
fi

# git setup
git config --global core.editor "vim"

# Link bin folder
if [ ! -d "$HOME/bin" ] || [ -z "$(ls -A "$HOME/bin" 2>/dev/null)" ]; then
    echo "Linking ~/bin -> $DOTFILES_DIR/bin"
    ln -sfn "$DOTFILES_DIR/bin" "$HOME/bin"
fi

echo "Install complete."
