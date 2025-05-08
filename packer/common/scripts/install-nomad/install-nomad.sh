#!/bin/bash

NOMAD_VERSION="${NOMAD_VERSION:=1.13.1+ent}"

set -euo pipefail

function install_lxc_task_driver {
  local -r version="0.1.0"

  echo "Installing LXC Task Driver"
  sudo apt install -y lxc lxc-templates
  sudo mkdir --parents "/opt/nomad/data/plugins"
  curl -O "https://releases.hashicorp.com/nomad-driver-lxc/${version}-rc2/nomad-driver-lxc_${version}-rc2_linux_amd64.zip"
  unzip nomad-driver-lxc_0.1.0-rc2_linux_amd64.zip
  sudo mv "nomad-driver-lxc" /"opt/nomad/data/plugins"
  sudo rm ./nomad-driver-lxc*.zip
  echo "Installing LXC Task Driver --> Complete!"
}

function create_nomad_user() {
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

function configure_consul_dns() {
# setup systemd-resolved to send *.consul DNS requests to Consul
sudo mkdir --parents /etc/systemd/resolved.conf.d/
local consul_dns=""
consul_dns=$(cat <<-EOF
DNS=localhost:8600
Domains=~consul
EOF
)
  echo -e "$consul_dns" | sudo tee /etc/systemd/resolved.conf.d/consul.conf
}

function setup_directories() {

  echo '[+] Configuring nomad directories'
  # create and manage permissions on directories
  sudo mkdir --parents --mode=0755 \
    "/etc/nomad.d" \
    "/etc/nomad.d/tls" \
    "/etc/nomad.d/jobs" \
    "/etc/nomad.d/jobs/registration-templates" \
    "/opt/nomad" \
    "/opt/nomad/bin" \
    "/opt/nomad/data" \
    "/opt/nomad/data/plugins" \
    ;
  sudo chown --recursive "consul:consul" \
    "/etc/nomad.d" \
    "/etc/nomad.d/tls" \
    "/etc/nomad.d/jobs" \
    "/etc/nomad.d/jobs/registration-templates" \
    "/opt/nomad" \
    "/opt/nomad/bin" \
    "/opt/nomad/data" \
    "/opt/nomad/data/plugins" \
    ;
}

function copy_tls_certs() {
  echo "[+] Transferring consul-ca and agent certs to /etc/nomad.d/tls"
  sudo cp /tmp/packer_files/cfg/tls/* "/etc/nomad.d/tls"
  sudo mv "/etc/nomad.d/tls/ca.pem" "/etc/nomad.d/tls/nomad-agent-ca.pem"
  sudo mv "/etc/nomad.d/tls/ca-key.pem" "/etc/nomad.d/tls/nomad-agent-ca-key.pem"
  sudo mv "/etc/nomad.d/tls/server.pem" "/etc/nomad.d/tls/nomad.pem"
  sudo mv "/etc/nomad.d/tls/server-key.pem" "/etc/nomad.d/tls/nomad-key.pem"

  echo "[+] Updating local certificate store with Consul CA Certificate Authority cert."
  sudo mkdir /usr/local/share/ca-certificates/nomad_certs --parents
  sudo chmod 0755 /usr/local/share/ca-certificates/nomad_certs
  sudo cp "/etc/nomad.d/tls/nomad-agent-ca.pem" "/usr/local/share/ca-certificates/nomad_certs/nomad-ca.crt"
  sudo chmod 0644 "/usr/local/share/ca-certificates/nomad_certs/nomad-ca.crt"
  sudo chmod 0755 "/etc/nomad.d/tls" -R
}

function install_cfssl_binaries() {
  for bin in cfssl cfssl-certinfo cfssljson
  do
    echo "Installing $bin..."
    curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
    sudo install /tmp/${bin} /usr/local/bin/${bin}
  done
}

function install_nomad_job_cfgs() {
  echo "[+] Transferring nomad job HCL files -> /etc/nomad.d/jobs"
  sudo cp /tmp/packer_files/cfg/nomad/configs/jobs/* "/etc/nomad.d/jobs"
  sudo chmod 0755 --recursive "/etc/nomad.d/jobs"
  sudo chown nomad:nomad --recursive "/etc/nomad.d/jobs"

}

function install_nomad() {
  local arch=""
  arch="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"

  echo "[+] Installing Nomad v$NOMAD_VERSION"
  curl \
    --silent "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${arch}.zip" \
    --output '/tmp/nomad.zip' \
    --location \
    --fail

  echo "[+] Unzipping /tmp/nomad.zip ($NOMAD_VERSION) --> /tmp/nomad"
  unzip \
    -o "/tmp/nomad.zip" \
    -d /tmp 1>/dev/null

  echo "[+] Moving /tmp/nomad binary --> /usr/local/bin/nomad"
  sudo mv "/tmp/nomad" "/usr/local/bin/nomad"
  sudo chown "nomad:nomad" "/usr/local/bin/nomad"
  sudo chmod a+x "/usr/local/bin/nomad"
}

function install_systemd_file() {
  systemd_file="$1"
  echo "*** Installing systemd file: $systemd_file"
  sudo cp "/tmp/packer_files/cfg/nomad/systemd/$systemd_file" /etc/systemd/system
  sudo chmod 0644 "/etc/systemd/system/$systemd_file"
  sudo systemctl enable "$systemd_file"
}

echo '***** Starting Nomad install'
create_nomad_user 'nomad' '/opt/nomad'
setup_directories
install_nomad
nomad -autocomplete-install
complete -C /usr/local/bin/nomad nomad
install_systemd_file nomad.service
configure_consul_dns
install_nomad_job_cfgs
install_cfssl_binaries
install_lxc_task_driver
