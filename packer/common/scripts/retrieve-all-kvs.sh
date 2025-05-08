#!/bin/bash

## ZenDesk Reference: https://hashicorp.zendesk.com/agent/tickets/101417
## T-Mobile Connection Timeouts at 14 Hrs -- Restore occurs >19 Hrs -- 1/3 of the snapshot being restored
##   -- Reasonable timeframe required (maintenance window)
##   -- Example: Replication east -> west cluster kv data
##   -- WAL Solution -- Will this help at all?
## Consul KV Snapshot unable to be taken due to KV size
## Recommendation for Consul KV Replicate hasn't been attempted yet.
## Consul Use Case: Relic --> stores runtime information in KV
##   2643755 Keys
## Scripted break-down for KV
##   - Breaks KV chunks into ~8-90Mi size files for future import
##   - Plans in pipeline to have KV replication

## Basic WAN Federation

while read -r key; do
    value="$( curl --silent "http://127.0.0.1:8500/v1/kv/$key" | jq -r '.[].Value' | base64 --decode )"
    echo -ne "$key:$value\n"
done < <(curl --silent "http://127.0.0.1:8500/v1/kv/?keys"| jq -r '.[]')