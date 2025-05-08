#!/bin/bash

## Set the Consul HTTP API address
CONSUL_HTTP_ADDR="http://your-consul-server-address:8500"
#
## Set your ACL token here
CONSUL_HTTP_TOKEN="your-acl-token"

# eval "$(cat /etc/profile.d/consul.sh)"

# List of endpoints from the Consul API that represent different resources
declare -A endpoints=(
  ["acl-tokens"]="/v1/acl/tokens"
  ["acl-roles"]="/v1/acl/roles"
  ["acl-policies"]="/v1/acl/policies"
  ["acl-binding-rules"]="/v1/acl/binding-rules"
  ["acl-auth-methods"]="/v1/acl/auth-methods"
  ["kv"]="/v1/kv/?keys=true&"
  ["sessions"]="/v1/session/list"
  ["services"]="/v1/catalog/services"
)

CONFIG_ENTRIES=( \
  api-gateway \
  bound-api-gateway \
  exported-services \
  http-route \
  ingress-gateway \
  inline-certificate \
  mesh \
  service-defaults \
  service-intentions \
  service-resolver \
  service-router \
  service-splitter \
  tcp-route \
  terminating-gateway \
)

function confirm_deletion() {
  read -p "Are you sure you want to delete $1? [y/N] " -n 1 -r
  echo    # Move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    return 0 # Confirmation received
  else
    return 1 # No confirmation
  fi
}

# Delete KV pairs
function delete_kv_pairs() {
  local namespace="$1"
  kv_keys=$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    "$CONSUL_HTTP_ADDR/v1/kv/?keys&namespace=$namespace" | jq -r '.[]')
  for key in $kv_keys; do
    if confirm_deletion "KV pair '$key' in namespace '$namespace'"; then
      curl -X DELETE -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/kv/$key?ns=$namespace"
    else
      echo "KV deletion aborted by user."
    fi
  done
}

# Function to delete service instances for ingress gateways
function delete_ingress_gateway_services() {
  local namespace="$1"
  local services
  services=$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    "$CONSUL_HTTP_ADDR/v1/health/ingress/service-name?ns=$namespace" | jq -r '.[].Service.ID')

  for service_id in $services; do
    if [[ -n "$service_id" ]]; then
      echo "Deleting ingress gateway service $service_id from namespace $namespace"
      curl -s -X DELETE -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
        "$CONSUL_HTTP_ADDR/v1/catalog/deregister" -d "{\"Node\":\"$service_id\", \"Namespace\":\"$namespace\"}"
    fi
  done
}

function delete_config_entries() {
  local namespace="$1"
  # Delete configuration entries
  for config in "${CONFIG_ENTRIES[@]}"; do
    # Fetch configuration entries of each kind
    entries=$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/config/$config?ns=$namespace" | jq -r '.[] | .Name')
    for entry in $entries; do
      if [ -n "$entry" ]; then # Check if entry is not empty
        if confirm_deletion "config entry '$entry' of kind '$config'" "$namespace"; then
          curl -X DELETE -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/config/$config/$entry?ns=$namespace"
        else
          echo "Deletion aborted by user."
        fi
      fi
    done
  done
}

function delete_catalog_services() {
  local namespace_name=$1
    local datacenter

    datacenter="$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR"/v1/agent/self | jq -r '.Config.Datacenter')"
    # Get a list of services within the namespace
    services=$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
      "${CONSUL_HTTP_ADDR}/v1/catalog/services?ns=${namespace_name}" | jq -r 'keys[]')
    # Loop through each service and deregister it
    for service in $services; do
      if confirm_deletion "service" "$service" "$namespace_name"; then
        # Retrieve the node and service ID required for deregistration
        service_info=$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
          "${CONSUL_HTTP_ADDR}/v1/catalog/service/${service}?ns=${namespace_name}")

        nodes=$(echo "$service_info" | jq -r '.[].Node')
        service_ids=$(echo "$service_info" | jq -r '.[].ServiceID')

        for node in $nodes; do
          for service_id in $service_ids; do
            # Create deregistration payload
            payload=$(jq -n --arg datacenter "$datacenter" --arg node "$node" --arg service_id "$service_id" \
              '{Datacenter: "$datacenter", Node: $node, ServiceID: $service_id}')
            # Deregister the service
            deregister_response=$(curl -s -X PUT -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
              -d "$payload" "${CONSUL_HTTP_ADDR}/v1/catalog/deregister")

            echo "Deregistration response for service '${service}' on node '${node}': $deregister_response"
          done
        done
      else
        echo "Deletion of service '${service}' cancelled."
      fi
    done
}

function delete_acl_resources() {

  query="ns=${namespace_name}"
  # Dry run, just list the resources
  response="$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  "${CONSUL_HTTP_ADDR}${endpoints[$resource]}?$query" | jq .)"
}

# Function to check if the namespace is empty
function is_namespace_empty() {
  local namespace_name="$1"

  for resource in "${!endpoints[@]}"; do
    printf '%s' "Checking for ${resource} in ${namespace_name} namespace:"
    if [ "$resource" = "kv" ]; then
      query="keys=true&ns=${namespace_name}"
    else
      query="ns=${namespace_name}"
    fi
    # Dry run, just list the resources
    response="$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
      "${CONSUL_HTTP_ADDR}${endpoints[$resource]}?$query" | jq .)"
    if ! { [[ -z $response ]] || [[ $response == "[]" ]] || [[ $response == "{}" ]]; }; then
      echo "$response"
      return 1
    else
      printf '%s\n' " no ${resource} found!"
    fi
  done
  return 0 # Namespace empty
}

# Function to list and delete resources from a namespace
function manage_namespace_resources() {
  local namespace_name=$1
  local dry_run=$2

  for resource in "${!endpoints[@]}"; do
    # Perform a dry run or actual deletion based on the flag
    if [ "$dry_run" = true ]; then
      printf '%s' "Checking for ${resource} in ${namespace_name} namespace:"
      if [ "$resource" = "kv" ]; then
        query="keys=true&ns=${namespace_name}"
      else
        query="ns=${namespace_name}"
      fi
      # Dry run, just list the resources
      response="$(curl -s -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
        "${CONSUL_HTTP_ADDR}${endpoints[$resource]}?$query" | jq .)"
      if [[ -z $response ]] || [[ $response == "[]" ]] || [[ $response == "{}" ]]; then
        printf '%s\n' " no ${resource} found!"
      else
        echo "$response"
      fi
    else
      delete_catalog_services "${namespace_name}"
      delete_config_entries "${namespace_name}"
      delete_kv_pairs "${namespace_name}"
      # After all deletions, check if namespace is empty
      if is_namespace_empty "$namespace"; then
        if confirm_deletion "namespace '$namespace'"; then
          # Call API to delete the namespace
          response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/namespace/$namespace")
          if [[ $response -eq 200 ]]; then
            echo "Namespace '$namespace' successfully deleted."
          else
            echo "Failed to delete namespace '$namespace'. HTTP response code: $response"
          fi
        else
          echo "Namespace deletion aborted by user."
        fi
      else
        echo "Namespace '$namespace' is not empty. Deletion skipped."
      fi
    fi
  done
}

# Main script starts here

# Check for --dry-run flag
DRY_RUN=false
if [[ " $* " =~ " --dry-run " ]]; then
  DRY_RUN=true
fi

# Gather the list of namespaces to be managed, excluding the script name and flags
NAMESPACES=()
for arg in "$@"; do
  if [[ "$arg" != "--dry-run" ]]; then
    NAMESPACES+=("$arg")
  fi
done

# If there are no namespaces provided, output the usage message
if [ ${#NAMESPACES[@]} -eq 0 ]; then
  echo "Usage: $0 [--dry-run] namespace1 [namespace2 ...]"
  exit 1
fi

# Iterate over the namespaces and manage their resources
for namespace_name in "${NAMESPACES[@]}"; do
  manage_namespace_resources "$namespace_name" "$DRY_RUN"
done

if [ "$DRY_RUN" = true ]; then
  echo "Dry run complete."
else
  echo "Resource management complete."
fi
