#!/bin/bash

CONSUL_TEMPLATE_VERSION="${CONSUL_TEMPLATE_VERSION:=0.40.0}"
ARCH="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"

set -euo pipefail

setup_directories() {
  echo '[+] Configuring consul directories'
  # create and manage permissions on directories
  sudo mkdir --parents --mode=0755 \
    "/etc/consul-template.d" \
    ;
  sudo chown --recursive consul:consul \
    "/etc/consul-template.d" \
    ;
}

install_consul_template() {
  echo "[+] Installing Consul-Template v${CONSUL_TEMPLATE_VERSION}"
  curl --silent \
    "https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_${ARCH}.zip" \
    --output /tmp/consul-template.zip \
    --location \
    --fail

  echo "[+] Unzipping /tmp/consul-template.zip (${CONSUL_TEMPLATE_VERSION}) --> /tmp/consul-template"
  unzip -o /tmp/consul-template.zip -d /tmp 1>/dev/null

  echo "[+] Moving /tmp/consul-template binary --> /usr/local/bin/consul-template"
  sudo mv /tmp/consul-template /usr/local/bin/consul-template
  sudo chown consul:consul /usr/local/bin/consul-template
  sudo chmod a+x /usr/local/bin/consul-template
}

echo '***** Starting Consul Template install'
setup_directories
install_consul_template