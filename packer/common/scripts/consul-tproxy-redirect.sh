#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# This is a small wrapper around `consul connect redirect-traffic` which
# Determines the user ID for the `consul` process and `envoy` sidecar
# prior to executing the command to install the redirect rules.
#
# Syntax is: consul-redirect-traffic <service name>

# Exit upon receiving any errors
set -o errexit

usage(){
  echo "Usage: $(basename "$0") <service_name>"
  exit 1
}

# Ensure a service name was provided
if [[ $# -eq 0 ]]; then
    usage
fi

# Obtain user IDs for consul and envoy
CONSUL_UID=$(id --user consul)
PROXY_UID=$(id --user envoy)

if [[ -f "/etc/consul.d/service-registration.json" ]]; then
  # CONFIGURED_PROXY_MODE=$(jq --raw-output .service.connect.sidecar_service.proxy.mode /etc/consul.d/service-registration.json)
  CONFIGURED_PROXY_MODE="$( curl ${CONSUL_HTTP_ADDR}/v1/catalog/service/${1}-sidecar-proxy | jq '.[] | .ServiceProxy.Mode' )"
  DIRECT_PROXY_MODE="direct"

  # Do not install the redirect rules if the proxy is operating in `direct` mode.
  if [[ "$CONFIGURED_PROXY_MODE" = "$${DIRECT_PROXY_MODE}" ]]; then
    exit
  fi
fi

consul connect redirect-traffic \
  -proxy-uid="${PROXY_UID}" \
  -exclude-uid="${CONSUL_UID}" \
   -proxy-inbound-port=20000 \
   -proxy-outbound-port=15001 \
   -exclude-inbound-port=22