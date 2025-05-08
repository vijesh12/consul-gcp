#!/bin/bash

SERVICE_PREFIX="${SERVICE_PREFIX:=redis}"

# Create svc_name empty array.
svc_names=()

# Populate array with redis test services
for i in $( curl -s "http://127.0.0.1:8500/v1/agent/services" | jq .[].Service | grep $SERVICE_PREFIX | tr '"' ' ' | xargs | tr ' ' '\n'); do
  svc_names+=("$i");
done

# Deregister each of the previously obtained services via API
for svc in "${svc_names[@]}"; do
  echo "[-] Deregistering Consul Service: $svc"
  curl --request PUT --silent "http://127.0.0.1:8500/v1/agent/service/deregister/$svc"
  sleep 1
  clear
done
echo "[+] Done!"
