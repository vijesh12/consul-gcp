#!/bin/bash

# Set Customer Specific Environmental Variables
export CONSUL_HTTP_ADDR="http://127.0.0.1:8500"
export CONSUL_HTTP_TOKEN=""


function snapshot_envoy_admin {
  local admin_api_port=$1
  local envoy_name=$2
  local dc=${3:-"$(curl -sk "${CONSUL_HTTP_ADDR}/v1/agent/self" | jq -r .Config.Datacenter)"}
  local dest="/tmp/envoy-snapshots/${dc}/${envoy_name}"

  mkdir -p "${dest}"
  wget "http://${admin_api_port}/config_dump?include_eds" -q -O - >"${dest}/config_dump.json"
  wget "http://${admin_api_port}/clusters?format=json" -q -O - >"${dest}/clusters.json"
  wget "http://${admin_api_port}/stats" -q -O - >"${dest}/stats.txt"
  wget "http://${admin_api_port}/stats/prometheus" -q -O - >"${dest}/stats_prometheus.txt"
}

