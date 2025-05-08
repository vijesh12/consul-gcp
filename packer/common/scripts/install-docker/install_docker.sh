#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo '*** Adding docker engine repository to apt sources lists'
sudo apt update 1>/dev/null

curl -fsSL https://download.docker.com/linux/ubuntu/gpg --silent | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

echo '*** Installing docker'
sudo apt update 1>/dev/null
sudo --preserve-env=DEBIAN_FRONTEND \
    apt install --yes 1>/dev/null \
        docker-ce \
        docker-ce-cli \
        containerd.io \
    ;
