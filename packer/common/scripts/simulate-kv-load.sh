#!/bin/bash

set -euo pipefail

# change the 100 to however many entries you want to do
KEY_PREFIX="consul-kv-load/test/secrets"
NUM_OF_KEYS="${NUM_OF_KEYS:=25}"
KB_SIZE=${KB_SIZE:=1258291} # Default KB Value to 4096 Bytes or 409.6 (< 512KB) | 1258291.2 = 1.2MB

# kv_max_value_size - (Advanced) Configures the maximum number of bytes for a kv request body to the /v1/kv endpoint.
# This limit defaults to raft's suggested max size (512KB).
# Note that tuning these improperly can cause Consul to fail in unexpected ways, it may potentially affect leadership
# stability and prevent timely heartbeat signals by increasing RPC IO duration. This option affects the txn endpoint
# too, but Consul 1.7.2 introduced txn_max_req_len which is the preferred way to set the limit for the txn endpoint.
# If both limits are set, the higher one takes precedence.

# txn_max_req_len - (Advanced) Configures the maximum number of bytes for a transaction request body to the
# /v1/txn endpoint. This limit defaults to raft's suggested max size (512KB). Note that tuning these improperly
# can cause Consul to fail in unexpected ways, it may potentially affect leadership stability and prevent
# timely heartbeat signals by increasing RPC IO duration.

## Agent Config
# limits.txn_max_req_len | 614.4KB = 614400 | 1.3MB = 1300000

generate_kv_blob() {
  # 512000 Bytes = 512KB 1228800
  local wanted_size=${KB_SIZE} # 524288 # 614.4KB
  local file_size=$(( ((wanted_size/12)+1)*12 ))
  local read_size=$((file_size*3/4))
  echo "Generating desired consul kv key value size - ${wanted_size}"
  dd if=/dev/urandom bs=${read_size count}=1 | tr -d '\n\r' | base64 > /tmp/random-kv-blob.txt
  truncate -s "${wanted_size}" /tmp/random-kv-blob.txt
}

for i in $( seq 1 "${NUM_OF_KEYS}" ); do
 generate_kv_blob
 while read -r data; do
  curl --request PUT --data @/tmp/random-kv-blob.txt "http://127.0.0.1:8500/v1/kv/$KEY_PREFIX-$i"
  continue 2
 done < <(cat /tmp/random-kv-blob.txt)
done

