#!/bin/bash

ENVOY_VERSION="${ENVOY_VERSION:=1.25.1}"
ARCH="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"

set -euo pipefail

setup_dd_log_dir() {
  echo '[+] Configuring envoy log directory'
  # create and manage permissions on directories
  sudo mkdir --parents --mode=0755 \
    "/var/log/envoy" \
    ;
  sudo chown --recursive "consul:consul" \
    "/var/log/envoy" \
    ;
}

create_envoy_user() {
    local username="${1}"
    local home_dir="${2}"

  echo "[+] Creating ${username} user | homedir: ${home_dir}"
  if ! getent passwd "${username}" >/dev/null ; then
    sudo /usr/sbin/adduser \
      --system \
      --home "${home_dir}" \
      --no-create-home \
      --shell /bin/false \
      "${username}"
    sudo /usr/sbin/groupadd --force --system "${username}"
    sudo /usr/sbin/usermod --gid "${username}" "${username}"
    # Add envoy user to consul group
    sudo /usr/sbin/usermod -a -G consul envoy
  fi
  echo "$username soft nofile 65536" | sudo tee -a 1>/dev/null /etc/security/limits.conf
  echo "$username hard nofile 65536" | sudo tee -a 1>/dev/null /etc/security/limits.conf
}

install_envoy() {
  echo "[+] Installing Envoy Version v${ENVOY_VERSION}"
  wget --quiet "https://github.com/tetratelabs/archive-envoy/releases/download/v${ENVOY_VERSION}/envoy-v${ENVOY_VERSION}-linux-${ARCH}.tar.xz" 1>/dev/null

  echo "[+] Unzipping (tar) Envoy v${ENVOY_VERSION}"
  sudo tar -xf "envoy-v${ENVOY_VERSION}-linux-${ARCH}.tar.xz" 1>/dev/null
  sudo chmod a+x "envoy-v${ENVOY_VERSION}-linux-${ARCH}/bin/envoy"

  echo "[+] Moving Envoy binary --> /usr/local/bin/envoy (v${ENVOY_VERSION})"
  sudo mv "envoy-v${ENVOY_VERSION}-linux-${ARCH}/bin/envoy" /usr/local/bin/envoy
  sudo rm -rf "envoy-v${ENVOY_VERSION}-linux-${ARCH}.tar.xz" "envoy-v${ENVOY_VERSION}-linux-${ARCH}"
}

echo '***** Starting Envoy install'
create_envoy_user envoy /opt/consul
setup_dd_log_dir
install_envoy