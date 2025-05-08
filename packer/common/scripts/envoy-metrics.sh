#!/usr/bin/env bash


set -e 

eval "$(cat /etc/profile.d/consul.sh)"

# Retrieve Envoy Stats Port
ENVOY_STATS_PORT="$(curl -sk \
  "${CONSUL_HTTP_ADDR}"/v1/config/proxy-defaults | \
  jq -r '.[] | .Config.envoy_stats_bind_addr | split(":")[1]')"

# Retrieve all non-zero/null Envoy stats
STATS="$(curl -sk \
  0:"$ENVOY_STATS_PORT"/stats?format=json | \
  jq -r '.[] | .[] | select(.value!=0)')"

# Gather Envoy metric stat names
METRICS=("$(echo "$STATS" | jq -r '[. | .name] | join(" ")' | tr '\n' ' ')")


METRICS=("$(echo "$STATS" | jq -r '. | .name' | tr '\n' ' ')")
echo "$STATS" | jq -r '[. | {name: .name, value: .value}] | sort_by(.value) | map("\(.name):\(.value)") | .[]'

echo "${#METRICS[@]}"





exit 0
curl -s localhost:8500/v1/config/service-defaults | jq .
curl -s 0:19001/clusters?format=json\&include_eds | jq -r '.cluster_statuses[] | .name'
curl -s 0:19001/clusters?format=json\&include_eds | jq -r '.cluster_statuses[] | select(.name|match("backend.*"))'
curl -s 0:19001/clusters?format=json\&include_eds | jq -r '.cluster_statuses[] | select(.name|match("backend.*")) | .host_statuses[] | .address[]'
curl -s 0:19001/clusters?format=json\&include_eds | jq -r '.cluster_statuses[] | select(.name|match("backend.*")) | .host_statuses[] | .stats[] | select(.name=="cx_connect_fail")'