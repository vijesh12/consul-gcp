#!/bin/bash

VAULT_VERSION="${VAULT_VERSION:=1.11.2+ent}"

set -euo pipefail

function create_vault_user() {
    username="$1"
    home_dir="$2"

  echo "[+] Creating $username user | homedir: $home_dir"
  if ! getent passwd "$username" >/dev/null ; then
    sudo /usr/sbin/adduser \
      --system \
      --home "$home_dir" \
      --no-create-home \
      --shell /bin/false \
      "$username"
    sudo /usr/sbin/groupadd --force --system "$username"
    sudo /usr/sbin/usermod --gid "$username" "$username"
  fi
}

function install_vault() {
  echo "[+] Installing Vault v$VAULT_VERSION"
  # Installs Vault System User and Configures vault.service systemd unit
  # --> vault binary at /usr/bin/vault
  # --> /usr/lib/systemd/system/vault.service
  # --> vault:x:998:997::/home/vault:/bin/false
  # --> Creates /opt/vault and /etc/vault.d directories
  # --> Gives baseline vault.hcl and vault.env files in /etc/vault.d directory
  # sudo apt-get install "vault-enterprise=$VAULT_VERSION"
  local arch=""
  arch="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"
  curl \
    --silent "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${arch}.zip" \
    --output '/tmp/vault.zip' \
    --location \
    --fail

  echo "[+] Unzipping /tmp/vault.zip ($VAULT_VERSION) --> /tmp/vault"
  unzip \
    -o "/tmp/vault.zip" \
    -d /tmp 1>/dev/null

  echo "[+] Moving /tmp/vault binary --> /usr/local/bin/vault"
  sudo mv "/tmp/vault" "/usr/local/bin/vault"
  sudo chown "vault:vault" "/usr/local/bin/vault"
  sudo chmod a+x "/usr/local/bin/vault"
}

function setup_directories() {

  echo '[+] Configuring vault directories'
  # create and manage permissions on directories
  sudo mkdir --parents --mode=0755 \
    "/etc/vault-agent.d" \
    "/etc/vault-agent.d/tls" \
    "/etc/vault-agent.d/templates" \
    "/etc/vault.d" \
    "/etc/vault.d/tls" \
    "/opt/vault" \
    "/opt/vault/bin" \
    "/opt/vault/data" \
    ;
  sudo chown --recursive "vault:vault" \
    "/etc/vault-agent.d" \
    "/etc/vault-agent.d/tls" \
    "/etc/vault-agent.d/templates" \
    "/etc/vault.d" \
    "/etc/vault.d/tls" \
    "/opt/vault" \
    "/opt/vault/bin" \
    "/opt/vault/data" \
    ;
}

function copy_tls_certs() {
  echo "[+] Transferring consul-ca and agent certs to /etc/vault.d/tls"
  sudo cp /tmp/packer_files/cfg/tls/* "/etc/vault.d/tls"
  sudo mv "/etc/vault.d/tls/ca.pem" "/etc/vault.d/tls/vault-agent-ca.pem"
  sudo mv "/etc/vault.d/tls/ca-key.pem" "/etc/vault.d/tls/vault-agent-ca-key.pem"
  sudo mv "/etc/vault.d/tls/server.pem" "/etc/vault.d/tls/vault.pem"
  sudo mv "/etc/vault.d/tls/server-key.pem" "/etc/vault.d/tls/vault-key.pem"

  echo "[+] Updating local certificate store with Consul CA Certificate Authority cert."
  sudo mkdir /usr/local/share/ca-certificates/vault_certs --parents
  sudo chmod 0755 /usr/local/share/ca-certificates/vault_certs
  sudo cp "/etc/vault.d/tls/vault-agent-ca.pem" "/usr/local/share/ca-certificates/vault_certs/vault-ca.crt"
  sudo chmod 0644 "/usr/local/share/ca-certificates/vault_certs/vault-ca.crt"
  sudo chmod 0755 "/etc/vault.d/tls" -R
}

function install_systemd_file() {
  systemd_file="$1"
  echo "[+] Installing systemd file: $systemd_file"
  sudo cp "/tmp/packer_files/cfg/vault/systemd/$systemd_file" /etc/systemd/system
  sudo chmod 0644 "/etc/systemd/system/$systemd_file"
  sudo systemctl enable "$systemd_file"
}

function install_utility_script() {
  utility_script="$1"
  destination_filename="$utility_script"

  echo "[+] Installing script $utility_script file as: $destination_filename"
  sudo cp --verbose "/tmp/packer_files/cfg/vault/$utility_script" "/usr/local/bin/$destination_filename"
  sudo chown --recursive "vault:vault" "/usr/local/bin/$destination_filename"
  sudo chmod a+x "/usr/local/bin/$destination_filename"
}

echo '***** Starting Vault install'
create_vault_user 'vault' '/opt/vault'
setup_directories
install_vault
install_systemd_file vault.service
install_systemd_file vault-agent.service
echo "*** Installing Vault agent templates file to: /etc/vault-agent.d/templates/"
sudo rsync -chavzP "/tmp/packer_files/cfg/vault/vault_agent_templates/" "/etc/vault-agent.d/templates/"
