#!/bin/bash

CONSUL_DOMAIN=consul
CONSUL_IP='127.0.0.1'
CONSUL_DNS_PORT=8600

install_dependencies() {
  echo "Installing dependencies"
  sudo apt-get -y -qq update
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
  sudo apt-get install -y iptables-persistent
}

configure_systemd_resolved() {
  UBUNTU_VERSION=$( lsb_release -s -r )
  if [ "${UBUNTU_VERSION}" == "18.04" ] || [ "${UBUNTU_VERSION}" == "20.04" ] || [ "${UBUNTU_VERSION}" == "22.04" ]; then
    echo "Configuring systemd-resolved to forward lookups of the '${CONSUL_DOMAIN}' domain to ${CONSUL_IP}:${CONSUL_DNS_PORT} in /etc/systemd/resolved.conf"
    sudo iptables -t nat -A OUTPUT -d ${CONSUL_IP} -p udp -m udp --dport 53 -j REDIRECT --to-ports "${CONSUL_DNS_PORT}"
    sudo iptables -t nat -A OUTPUT -d ${CONSUL_IP} -p tcp -m tcp --dport 53 -j REDIRECT --to-ports "${CONSUL_DNS_PORT}"
    sudo iptables-save | sudo tee /etc/iptables/rules.v4
    sudo sed -i "s/#DNS=/DNS=${CONSUL_IP}/g" /etc/systemd/resolved.conf
    sudo sed -i "s/#Domains=/Domains=~${CONSUL_DOMAIN}/g" /etc/systemd/resolved.conf
  else
    echo "Cannot install on this version of GNU Linux"
    exit 1
  fi
}
echo "**** Starting systemd-resolved configuration"
install_dependencies
configure_systemd_resolved
echo "systemd-resolved configuration complete!"