#!/bin/bash

set -euo pipefail

function install_cni_plugins() {
  local -r version="$1"

  local arch=""
  arch="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"

  echo "[+] Downloading (curl) CNI Plugin v$version - https://github.com/containernetworking/plugins"
  curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v${version}/cni-plugins-linux-${arch}-v${version}.tgz"
  sudo mkdir -p /opt/cni/bin

  echo "[+] Unzipping (tar) CNI Plugin v$version"
  sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz 1>/dev/null

  echo "[+] Updating /proc/sys/net/bridge/bridge-nf-call ip and arp tables"
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-arptables
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables

  echo "[+] Updating /etc/sysctl.d/80-cni.conf with networking bridge settings."
cat <<CONF | sudo tee /etc/sysctl.d/80-cni.conf
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
CONF
}

install_cni_plugins '1.0.1'

