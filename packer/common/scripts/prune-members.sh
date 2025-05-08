#!/bin/sh

set -e

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --wan, -w           Prune WAN members only.
  --all, -a           Prune both LAN and WAN members.
  --token, -t TOKEN   Consul ACL Token with 'operator:write' permissions.
  --help              Display this help message.
EOF
  exit 1
}

now(){ date '+%d/%m/%Y-%H:%M:%S'; }

# Info function to display informational messages
info() { printf "%s \033[94m%s\033[0m %s\n" "$(now)" "[INFO]" "$@"; }

# Warn function to display warning messages
warn() { printf "%s \033[93m%s\033[0m %s\n" "$(now)" "[WARN]" "$@"; }

# Error function to display error messages and exit
err() {
    echo
    printf "%s \033[91m%s\033[0m %s\n" "$(now)" "[ERROR]" "$1" # Red text for errors
    shift
    for msg in "$@"; do
      echo "    $msg"
    done
    echo
    exit 1
}

CONSUL_HTTP_TOKEN=""

## Consul Members Status Enums
#   0: "None"
#   1: "Alive"
#   2: "Leaving"
#   3: "Left"
#   4: "Failed"

prune_members() {
    scope="$1"
    url="${CONSUL_HTTP_ADDR}/v1/agent/members"
    [ "$scope" = "wan" ] && url="${url}?wan=1"

    info "====> Starting pruning of ${scope} members: "

    info "Fetching members with status 'left' in ${scope} scope..."
    members=$(curl -sk --header "X-Consul-Token:${CONSUL_HTTP_TOKEN}" "$url" | jq -r '.[] | select(.Status == 3 or .Status == 2) | .Name')

    if [ -z "$members" ]; then
        warn "No members to prune in ${scope} pool!"
        return
    fi

    echo "$members" | while IFS= read -r member; do
        info "  ==> Pruning ${member}..."
        response=$(curl -sk --header "X-Consul-Token:${CONSUL_HTTP_TOKEN}" -X PUT "${CONSUL_HTTP_ADDR}/v1/agent/force-leave/$member?prune")
        if [ $? -ne 0 ]; then
            warn "Failed to prune ${member} -- Response: ${response}"
        else
            info "Successfully pruned ${member}."
        fi
    done
}

# Initialize options
PRUNE_LAN=false
PRUNE_WAN=false

# Parse flags
while [ "$#" -gt 0 ]; do
    case "$1" in
        --wan|-w)
            PRUNE_WAN=true
            ;;
        --all|-a)
            PRUNE_LAN=true
            PRUNE_WAN=true
            ;;
        --token|-t)
            shift
            CONSUL_HTTP_TOKEN="$1"
            if [ -z "$CONSUL_HTTP_TOKEN" ]; then
              err "Null token value passed. --token requires a value."
            fi
            ;;
        --help|-h)
            usage
            ;;
        *)
            err "Invalid option: $1"
            ;;
    esac
    shift
done

# Default behavior if neither --wan nor --all is specified
if [ "$PRUNE_LAN" = false ] && [ "$PRUNE_WAN" = false ]; then
    PRUNE_LAN=true
fi

# Execute pruning based on options
if [ "$PRUNE_LAN" = true ]; then
    prune_members "lan"
    info "====> Completed pruning of LAN members"
fi

if [ "$PRUNE_WAN" = true ]; then
    prune_members "wan"
    info "====> Completed pruning of WAN members"
fi
