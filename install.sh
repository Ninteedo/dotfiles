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

filter_available() {
    local p avail
    case "$PM" in
        apt)    for p in "$@"; do apt-cache show "$p" &>/dev/null && echo "$p"; done ;;
        pacman) for p in "$@"; do pacman -Si "$p" &>/dev/null && echo "$p"; done ;;
        dnf)
            avail=$(dnf repoquery --quiet --available --queryformat $'%{name}\n' "$@" 2>/dev/null)
            for p in "$@"; do grep -qx "$p" <<<"$avail" && echo "$p"; done
            ;;
    esac
}

MISSING_PKGS=()
has_missing() { [[ " ${MISSING_PKGS[*]} " == *" $1 "* ]]; }

install_packages() {
    local wanted=("$@") found=() missing=() p
    mapfile -t found < <(filter_available "${wanted[@]}")
    for p in "${wanted[@]}"; do
        [[ " ${found[*]} " == *" $p "* ]] || missing+=("$p")
    done
    MISSING_PKGS=("${missing[@]}")

    if [ "${#found[@]}" -eq 0 ]; then
        echo "Warning: none of the requested packages were found in the repositories."
        return 1
    fi

    echo "Installing ${#found[@]} packages in one transaction: ${found[*]}"
    if pkg_install "${found[@]}" 2>&1; then
        echo "Packages installed."
    else
        echo "Warning: package installation failed."
        return 1
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Not available in the enabled repositories: ${missing[*]}"
    fi
}

# Packages
CORE_PKGS=(zsh git curl neovim)
OPTIONAL_PKGS=(duf sd ripgrep btop fzf ranger tmux bat eza lazygit rsync)
case "$PM" in
    apt)    EXTRA_PKGS=(gpg locales) ;;       # gpg: eza repo key, locales: locale-gen
    dnf)    EXTRA_PKGS=(glibc-langpack-en) ;; # Fedora ships locales as langpacks
    *)      EXTRA_PKGS=() ;;
esac

if [ "$PM" = "unknown" ]; then
    echo "No supported package manager found (apt, pacman, dnf), skipping package installation."
elif has_sudo; then
    echo "Sudo privileges detected, installing packages with $PM (log: $LOG_FILE)..."

    if [ "$PM" = "apt" ]; then
        sudo apt-get update -qq >>"$LOG_FILE" 2>&1 || echo "Warning: apt update failed."
    fi

    install_packages "${CORE_PKGS[@]}" "${OPTIONAL_PKGS[@]}" "${EXTRA_PKGS[@]}"

    # Third-party sources, only when the distro repos don't carry the package
    if [ "$PM" = "apt" ] && has_missing eza; then
        echo "Adding the eza apt repository..."
        {
            sudo mkdir -p /etc/apt/keyrings &&
            curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg &&
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null &&
            sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list &&
            sudo apt-get update -qq &&
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq eza
        } >>"$LOG_FILE" 2>&1 \
            && echo "eza installed." \
            || echo "Warning: eza installation failed (see $LOG_FILE)."
    fi

    if [ "$PM" = "dnf" ] && has_missing lazygit; then
        echo "Adding the lazygit COPR repository..."
        {
            sudo dnf install -y -q dnf-plugins-core &&
            sudo dnf -y copr enable dejan/lazygit &&
            sudo dnf install -y -q lazygit
        } >>"$LOG_FILE" 2>&1 \
            && echo "lazygit installed." \
            || echo "Warning: lazygit installation failed (see $LOG_FILE)."
    fi

    # Debian/Ubuntu name the bat binary batcat
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi
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
