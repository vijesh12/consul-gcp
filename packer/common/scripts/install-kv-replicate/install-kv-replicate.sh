#!/bin/bash

set -euo pipefail

ARCH="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"
CONSUL_REPLICATE_VERSION="${CONSUL_REPLICATE_VERSION:=0.4.0}"

install_kv_replicate() {
  echo "[+] Installing Consul Replicate v${CONSUL_REPLICATE_VERSION}"
  curl \
    --silent "https://releases.hashicorp.com/consul-replicate/${CONSUL_REPLICATE_VERSION}/consul-replicate_${CONSUL_REPLICATE_VERSION}_linux_${ARCH}.zip" \
    --output /tmp/consul-replicate.zip \
    --location \
    --fail

  echo "[+] Unzipping /tmp/consul-replicate.zip (${CONSUL_REPLICATE_VERSION}) --> /tmp/consul-replicate"
  unzip \
    -o /tmp/consul-replicate.zip \
    -d /tmp 1>/dev/null

  echo "[+] Moving /tmp/consul-replicate binary --> /usr/local/bin/consul-replicate"
  sudo mv /tmp/consul-replicate /usr/local/bin/consul-replicate
  sudo chown consul:consul /usr/local/bin/consul-replicate
  sudo chmod a+x /usr/local/bin/consul-replicate
}

setup_directories() {
  echo '[+] Configuring consul-replicate directories'
  # create and manage permissions on directories
  sudo mkdir --parents --mode=0755 \
    /etc/consul-replicate.d \
    ;
  sudo chown --recursive consul:consul \
    /etc/consul-replicate.d \
    ;
}

set_base_config() {
  echo "[+] Creating base consul-replicate configuration file"
(
  cat <<-EOF
consul {
  address = "https://localhost:8501"
  retry {
    enabled     = true
    attempts    = 12
    backoff     = "250ms"
    max_backoff = "1m"
  }
  ssl {
    enabled = true
    verify  = false
    cert    = "/etc/consul.d/tls/consul.pem"
    key     = "/etc/consul.d/tls/consul-key.pem"
    ca_cert = "/etc/consul.d/tls/consul-agent-ca.pem"
  }
}
kill_signal = "SIGINT"
log_level   = "debug"
max_stale   = "10m"
pid_file    = "/etc/consul-replicate.d/.consul-replicate"
prefix {
  source      = "consul-kv-load/test/secrets"
  datacenter  = "us-east-2"
  destination = "consul-kv-load/test/secrets"
}
reload_signal = "SIGHUP"

# This is the path in Consul to store replication and leader status.
status_dir    = "service/consul-replicate/statuses"

syslog {
  enabled  = true
  facility = "LOCAL5"
}
wait {
  min = "5s"
  max = "10s"
}
EOF
) > /etc/consul-replicate.d/config.hcl
}

setup_directories
set_base_config
install_kv_replicate