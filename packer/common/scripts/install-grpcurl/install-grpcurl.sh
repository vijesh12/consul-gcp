#!/bin/bash

set -euo pipefail

GRPCURL_LATEST_RELEASE="$(curl -s https://api.github.com/repos/fullstorydev/grpcurl/releases/latest | jq -r '.tag_name')"
GRPCURL_VERSION="${GRPCURL_VERSION:="${GRPCURL_LATEST_RELEASE}"}"
ARCH="$(uname -m)"
URL="https://github.com/fullstorydev/grpcurl/releases/download/${GRPCURL_VERSION}/grpcurl_$(echo "${GRPCURL_VERSION}" | tr -d 'v')_linux_${ARCH}.tar.gz"


install_grpcurl() {
  echo "[+] Installing grpcurl version ${GRPCURL_VERSION}"
  curl -sSL "${URL}" | sudo tar -xz -C /usr/local/bin
  if command -v grpcurl >/dev/null 2>&1; then
    echo "***** grpcurl successfully installed!"
  fi
}

echo '***** Start: grpcurl install'
install_grpcurl