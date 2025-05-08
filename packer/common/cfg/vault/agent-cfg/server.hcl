# Full configuration options can be found at https://www.vaultproject.io/docs/configuration

ui = true

#mlock = true
#disable_mlock = true
#storage "consul" {
#  address       = "http://127.0.0.1:8500"
#  path          = "vault/"
#  tls_ca_file   = "/etc/consul.d/consul-agent-ca.pem"
#  tls_cert_file = "/etc/consul.d/dc1-client-consul.pem"
#  tls_key_file  = "/etc/consul.d/dc1-client-consul-key.pem"
#}

api_addr = "http://localhost:8200"
cluster_addr = "https://localhost:8201"
plugin_directory = "/etc/vault.d/vault_plugins"

# HTTP listener
#listener "tcp" {
# address = "0.0.0.0:8200"
# tls_disable = 0
#}

# HTTPS listener
listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_cert_file      = "/opt/vault/tls/tls.crt"
  tls_key_file       = "/opt/vault/tls/tls.key"
  tls_client_ca_file = "/opt/vault/tls/tls.crt"
  tls_disable        = "true"
}

service_registration "consul" {
  address = "127.0.0.1:8500"
  service_address = ""
}

# Enterprise license_path
# This will be required for enterprise as of v1.8
license_path = "/vagrant/configs/vault/enterprise-license/vault.hclic"
