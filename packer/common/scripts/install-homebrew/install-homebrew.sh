#!/bin/bash

set -euo pipefail

install_homebrew() {
    echo "[+] Installing Homebrew for Linux"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

brew_postinstall() {
    echo "[+] Updating ${HOME}/.bashrc"
    echo >> /home/ubuntu/.bashrc
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/ubuntu/.bashrc

    echo "[+] Installing 'build-essential' package from apt repo"
    sudo apt-get install --yes 1>/dev/null \
            build-essential
}

install_gcc() {
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    brew install gcc
}



