#!/usr/bin/env bash

eval "$(cat /etc/profile.d/consul.sh)"

# shellcheck disable=SC2154
prepared_query="$(cat <<-EOF
{
  "Name": "",
  "Session": "",
  "Token": "",
  "Template": {
    "Type": "name_prefix_match",
    "Regexp": "^(.*)$",
    "RemoveEmptyTags": false
  },
  "Service": {
    "Service": "\${name.full}",
    "Failover": {
      "NearestN": 2,
      "Datacenters": null,
      "Targets": null
    },
    "OnlyPassing": true,
    "IgnoreCheckIDs": null,
    "Near": "_agent",
    "Tags": null,
    "NodeMeta": null,
    "ServiceMeta": null,
    "Connect": false,
    "Peer": ""
  },
  "DNS": {
    "TTL": "10s"
  }
}
EOF
)"

response="$(curl --silent \
  --request POST \
  --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "$prepared_query" \
  "${CONSUL_HTTP_ADDR}"/v1/query)"

# Check response
if [ -n "$(echo "$response" | jq -r '.ID')" ]; then
  echo "Catch all prepared query for type applied successfully!."
  curl -s "${CONSUL_HTTP_ADDR}"/v1/query | jq .
else
  echo "Failed to apply catch all prepared query."
  echo "Response: $response"
fi

echo "Done applying prepared query"