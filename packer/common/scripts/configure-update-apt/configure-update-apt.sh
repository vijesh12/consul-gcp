#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

install_dependencies() {
echo '[+] Updating apt package lists (apt-get update)'
sudo --preserve-env=DEBIAN_FRONTEND \
  apt update 1>/dev/null

echo '[+] Performing apt dist-upgrade (apt dist-upgrade)'
sudo --preserve-env=DEBIAN_FRONTEND \
    apt dist-upgrade --yes 1>/dev/null

echo '[+] Installing additional dependencies via apt (apt install)'
sudo --preserve-env=DEBIAN_FRONTEND \
    apt install --yes 1>/dev/null \
        dnsutils \
        jq \
        less \
        moreutils \
        net-tools \
        nmap \
        traceroute \
        netcat \
        socat\
        rsync \
        unzip \
        vim \
        curl \
        libcap2-bin \
        wget \
        software-properties-common \
        apt-transport-https gnupg \
        ca-certificates \
        iptables-persistent \
        sysstat \
        logrotate \
    ;

echo '[+] Installing aws-cli'
curl --silent 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' --output /tmp/awscliv2.zip
unzip \
  -o /tmp/awscliv2.zip \
  -d /tmp/awscliv2 1>/dev/null
sudo /tmp/awscliv2/aws/install 1>/dev/null
}

add_hashicorp_apt_repo() {
  local arch
  arch="$( [[ "$(uname -m)" =~ aarch64|arm64 ]] && echo arm64 || echo amd64)"
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DA418C88A3219F7B || echo "[-] apt-key DA418C88A3219F7B not added"
  sudo curl \
    --fail \
    --silent \
    --location \
    --show-error \
    https://apt.releases.hashicorp.com/gpg \
    | sudo apt-key add -
  sudo apt-add-repository "deb [arch=${arch}] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  echo "[+] Updating apt repository with HashiCorp packages (apt update)"
  sudo --preserve-env=DEBIAN_FRONTEND \
    apt update 1>/dev/null
}

echo "**** Starting initial apt configuration"
add_hashicorp_apt_repo
install_dependencies

echo "*** Setting ubuntu user open file limits to 65536"
echo "ubuntu soft nofile 65536" >> /etc/security/limits.conf
echo "ubuntu hard nofile 65536" >> /etc/security/limits.conf

echo "+++++ Apt configuration complete!"
