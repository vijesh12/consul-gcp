#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# This is a small helper script to clean up iptables rules installed by
# Consul when the proxy stops or restarts.
#
# Syntax is: consul-cleanup-iptables

# Exit upon receiving any errors
set -o errexit

# Remove rules from NAT table
sudo iptables --table nat --flush

# Delete empty chains
declare -a consul_chains=("INBOUND" "IN_REDIRECT" "OUTPUT" "REDIRECT")

for i in "${consul_chains[@]}"
do
  sudo iptables --table nat --delete-chain "CONSUL_PROXY_${i}"
done

# Remove the CONSUL_DNS_REDIRECT chain that is created by Consul 1.11.x
# (Ignore exit code so that this continues to run on older Consul versions)
sudo iptables --table nat --delete-chain "CONSUL_DNS_REDIRECT" || true