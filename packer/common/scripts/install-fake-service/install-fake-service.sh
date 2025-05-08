#!/usr/bin/env bash

# FRB BOS Version Info: Consul Version 1.11.4+ent | Vault Version 1.10.0+ent
FAKE_VERSION="${FAKE_VERSION:="0.25.2"}"
ARCH="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"
PLATFORM=$(uname | tr '[:upper:]' '[:lower:]')
URL="https://github.com/nicholasjackson/fake-service/releases/download/v${FAKE_VERSION}/fake_service_${PLATFORM}_${ARCH}.zip"

install_fake_svc() {
  echo "Installing Fake Service v${FAKE_VERSION}"
  wget -q "${URL}" -O /tmp/fake-service.zip
  unzip \
    -o /tmp/fake-service.zip \
    -d /tmp 1>/dev/null
  chmod a+x /tmp/fake-service
  mv /tmp/fake-service /usr/local/bin/fake-service
}

install_fake_svc


