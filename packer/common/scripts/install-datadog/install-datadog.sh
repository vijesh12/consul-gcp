#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo '*** Adding APT package sources for Datadog'
echo 'deb [signed-by=/usr/share/keyrings/datadog-archive-keyring.gpg] https://apt.datadoghq.com/ stable 7' \
  | sudo tee /etc/apt/sources.list.d/datadog.list
sudo touch /usr/share/keyrings/datadog-archive-keyring.gpg
sudo chmod a+r /usr/share/keyrings/datadog-archive-keyring.gpg
curl -s https://keys.datadoghq.com/DATADOG_APT_KEY_CURRENT.public | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch
curl -s https://keys.datadoghq.com/DATADOG_APT_KEY_382E94DE.public | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch
curl -s https://keys.datadoghq.com/DATADOG_APT_KEY_F14F620E.public | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch

echo '*** Installing datadog-agent package'
sudo --preserve-env=DEBIAN_FRONTEND \
  apt-get update 1>/dev/null
sudo --preserve-env=DEBIAN_FRONTEND \
  apt-get install --yes 1>/dev/null \
  datadog-agent \
  datadog-signing-keys \
  ;

echo "*** Creating consul.d directory for consul datadog metrics conf"
sudo mkdir --parents /etc/datadog-agent/conf.d/consul.d

echo "*** Creating envoy.d directory for consul-connect envoy datadog metrics conf"
sudo mkdir --parents /etc/datadog-agent/conf.d/envoy.d

echo '*** Adding dd-agent to systemd-journal group (allow Datadog agent to stream journald logs)'
sudo usermod \
    --append \
    --groups=systemd-journal \
    dd-agent

echo '*** Adding dd-agent to consul group (allow Datadog agent to stream consul logs)'
sudo usermod \
    --append \
    --groups=consul \
    dd-agent

echo "*** Setting dd-agent user open file limits to 65536"
echo "dd-agent soft nofile 65536" >> /etc/security/limits.conf
echo "dd-agent hard nofile 65536" >> /etc/security/limits.conf

echo '*** Disabling datadog-agent service'
sudo systemctl disable --now datadog-agent.service


