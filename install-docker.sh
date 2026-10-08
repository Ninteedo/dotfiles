#!/bin/bash
# Installs Docker Engine and the Docker Compose plugin if they are missing.
# Supports Debian/Ubuntu (and derivatives), Fedora, and Arch (and derivatives).
#
# Usage: ./install_docker.sh [--no-group]
#   --no-group   do not add the current user to the "docker" group
#                (membership is root-equivalent, so skip it if you prefer sudo)

ADD_TO_GROUP=1
for arg in "$@"; do
    case "$arg" in
        --no-group) ADD_TO_GROUP=0 ;;
        -h|--help)  sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

die() { echo "Error: $*" >&2; exit 1; }

if [ "$(id -u)" = "0" ]; then
    die "Do not run this script as root."
fi

command -v sudo &>/dev/null && sudo -l &>/dev/null \
    || die "Sudo privileges are required."

have_docker()  { command -v docker &>/dev/null; }
have_compose() { have_docker && docker compose version &>/dev/null; }

if have_docker && have_compose; then
    echo "Docker and Docker Compose are already installed:"
    docker --version
    docker compose version
    NEED_DOCKER=0
    NEED_COMPOSE=0
else
    NEED_DOCKER=0
    NEED_COMPOSE=0
    have_docker  || NEED_DOCKER=1
    have_compose || NEED_COMPOSE=1
fi

# Detect package manager
if command -v apt-get &>/dev/null; then
    PM=apt
elif command -v pacman &>/dev/null; then
    PM=pacman
elif command -v dnf &>/dev/null; then
    PM=dnf
else
    PM=unknown
fi

add_repo_apt() {
    [ -f /etc/apt/sources.list.d/docker.list ] && return 0

    # shellcheck disable=SC1091
    . /etc/os-release
    local distro codename
    # Ubuntu and its derivatives (Mint, Pop!_OS...) use the ubuntu repo
    if [ "${ID:-}" = "ubuntu" ] || [[ " ${ID_LIKE:-} " == *" ubuntu "* ]]; then
        distro=ubuntu
        codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    else
        distro=debian
        codename="${VERSION_CODENAME:-}"
    fi
    [ -n "$codename" ] || die "Could not determine the distribution codename."

    echo "Adding Docker apt repository ($distro $codename)..."
    sudo apt-get update || die "apt update failed."
    sudo apt-get install -y ca-certificates curl || die "Could not install prerequisites."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "https://download.docker.com/linux/$distro/gpg" \
        -o /etc/apt/keyrings/docker.asc || die "Could not download Docker's GPG key."
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro $codename stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update || die "apt update failed after adding the Docker repository."
}

add_repo_dnf() {
    [ -f /etc/yum.repos.d/docker-ce.repo ] && return 0

    echo "Adding Docker dnf repository..."
    sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo \
        -o /etc/yum.repos.d/docker-ce.repo || die "Could not download Docker's repo file."
}

install_docker() {
    case "$PM" in
        apt)
            add_repo_apt
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin
            ;;
        dnf)
            add_repo_dnf
            sudo dnf install -y docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin
            ;;
        pacman)
            # No -Sy on purpose: partial upgrades are unsupported on Arch.
            # If this fails with 404s, run 'sudo pacman -Syu' first.
            sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx
            ;;
        *)
            die "No supported package manager found (apt, pacman, dnf)."
            ;;
    esac
}

install_compose_only() {
    case "$PM" in
        apt) add_repo_apt; sudo apt-get install -y docker-compose-plugin ;;
        dnf) add_repo_dnf; sudo dnf install -y docker-compose-plugin ;;
        pacman) sudo pacman -S --needed --noconfirm docker-compose ;;
        *) die "No supported package manager found (apt, pacman, dnf)." ;;
    esac
}

if [ "$NEED_DOCKER" = "1" ]; then
    echo "Docker is not installed, installing Docker Engine and Compose..."
    install_docker || die "Docker installation failed."
elif [ "$NEED_COMPOSE" = "1" ]; then
    echo "Docker is installed but the Compose plugin is missing, installing it..."
    install_compose_only || die "Docker Compose installation failed."
fi

# Start the service (skipped in containers/WSL setups without systemd)
if [ "$NEED_DOCKER" = "1" ]; then
    if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
        sudo systemctl enable --now docker || echo "Warning: could not enable the docker service."
    else
        echo "Note: systemd is not running, start the Docker daemon manually."
    fi
fi

# Group membership
if [ "$ADD_TO_GROUP" = "1" ] && ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    getent group docker &>/dev/null || sudo groupadd docker
    sudo usermod -aG docker "$USER"
    echo "Added $USER to the docker group."
    echo "Note: this is root-equivalent access. Log out and back in (or run 'newgrp docker') for it to apply."
fi

echo
if have_docker; then
    docker --version
    docker compose version 2>/dev/null || echo "Warning: 'docker compose' is not available."
else
    die "Docker still not found after installation."
fi
echo "Docker setup complete."
