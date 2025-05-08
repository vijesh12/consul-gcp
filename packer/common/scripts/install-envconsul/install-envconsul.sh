#!/bin/bash
#
# install-envconsul.sh
#
# Installs HashiCorp envconsul and prepares runtime directories.
#   • Honors $ENVCONSUL_VERSION if already set; otherwise defaults to 0.13.3
#   • Detects CPU architecture (amd64 | arm64)
#   • Creates /etc/envconsul.d owned by consul:consul
#   • Places the binary at /usr/local/bin/envconsul

ENVCONSUL_VERSION="${ENVCONSUL_VERSION:=0.13.3}"
ARCH="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"

set -euo pipefail

setup_directories() {
  echo "[+] Configuring envconsul directories"
  sudo mkdir --parents --mode=0755 /etc/envconsul.d
  sudo chown --recursive consul:consul /etc/envconsul.d
}

install_envconsul() {
  echo "[+] Installing envconsul v${ENVCONSUL_VERSION}"
  curl --silent --location --fail \
    "https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_${ARCH}.zip" \
    --output /tmp/envconsul.zip

  echo "[+] Unzipping /tmp/envconsul.zip (${ENVCONSUL_VERSION}) → /tmp/envconsul"
  unzip -o /tmp/envconsul.zip -d /tmp 1>/dev/null

  echo "[+] Moving /tmp/envconsul binary → /usr/local/bin/envconsul"
  sudo mv /tmp/envconsul /usr/local/bin/envconsul
  sudo chown consul:consul /usr/local/bin/envconsul
  sudo chmod a+x /usr/local/bin/envconsul
}

echo "***** Starting envconsul install"
setup_directories
install_envconsul
