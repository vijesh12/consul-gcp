#!/bin/bash

## ZenDesk Reference: https://hashicorp.zendesk.com/agent/tickets/101417
## T-Mobile Connection Timeouts at 14 Hrs -- Restore occurs > 19 Hrs -- 1/3 of the snapshot being restored
## Consul KV Snapshot unable to be taken due to KV size
## Recommendation for Consul KV Replicate hasn't been attempted yet.
## Consul Use Case: Relic --> stores runtime information in KV
##   2643755 Keys
## Scripted break-down for KV
##   - Breaks KV chunks into ~8-90Mi size files for future import

# kv_max_value_size - (Advanced) Configures the maximum number of bytes for a kv request body to the /v1/kv endpoint.
# This limit defaults to raft's suggested max size (512KB).
# Note that tuning these improperly can cause Consul to fail in unexpected ways, it may potentially affect leadership
# stability and prevent timely heartbeat signals by increasing RPC IO duration. This option affects the txn endpoint
# too, but Consul 1.7.2 introduced txn_max_req_len which is the preferred way to set the limit for the txn endpoint.
# If both limits are set, the higher one takes precedence.
# T-Mobile: 1.3MB

# txn_max_req_len - (Advanced) Configures the maximum number of bytes for a transaction request body to the
# /v1/txn endpoint. This limit defaults to raft's suggested max size (512KB). Note that tuning these improperly
# can cause Consul to fail in unexpected ways, it may potentially affect leadership stability and prevent
# timely heartbeat signals by increasing RPC IO duration.
# source /etc/consul.d/consul.env

KEY_PREFIX="consul-kv-load/test/secrets"

tree_payload=$( cat <<-EOF
[
  {
    "KV": {
      "Verb": "get-tree",
      "Key": "${KEY_PREFIX}"
    }
  }
]

EOF
)

echo -ne "Apply get-tree for following payload:\n ${tree_payload}"
curl --silent \
    --request PUT \
    --data "${tree_payload}" \
    http://127.0.0.1:8500/v1/txn > txn_get-tree.json