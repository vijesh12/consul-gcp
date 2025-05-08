#!/usr/bin/env bash

script="$(basename "$0" .sh)"
eval "$(cat scripts/logging.sh)"
eval "$(cat scripts/formatting.env)"

# Set default CONSUL_HTTP_ADDR if not provided
if [ -z "$CONSUL_HTTP_ADDR" ]; then
    CONSUL_HTTP_ADDR=http://127.0.0.1:8500
fi
export CONSUL_HTTP_TOKEN

# Function to trigger staggered leadership election swap with optional snapshot backups/restores
trigger_leadership_election() {
    local duration=$1
    local use_snapshots=$2
    local chaos_min_interval=$3
    local chaos_max_interval=$4
    local end_time=$((SECONDS + duration))
    local servers
    local interval
    local snapshot_file="/tmp/consul_snapshot.snap"

    # Function to get current Consul leader via API
    get_consul_leader() {
        consul_leader_addr=$(curl -s -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" "${CONSUL_HTTP_ADDR}/v1/status/leader" | jq -r | cut -d: -f1)
        if [ -z "$consul_leader_addr" ]; then
            info "${script}: Could not determine the current leader | CONSUL_HTTP_ADDR: ${CONSUL_HTTP_ADDR} | CONSUL_HTTP_TOKEN: ${CONSUL_HTTP_TOKEN}"
            return 1
        fi

        # Fetch the leader's node details
        local consul_leader_info

        consul_leader_info=$(curl -s -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" "${CONSUL_HTTP_ADDR}/v1/agent/members" | jq -r --arg leader "$consul_leader_addr" '.[] | select(.Addr == $leader) | {Name, Addr, ID: .Tags.id}')
        consul_leader_name=$(echo "$consul_leader_info" | jq -r .Name)
        consul_leader_id=$(echo "$consul_leader_info" | jq -r .ID)

        print_msg "${script}: Current leader Information: "\
            "Name: $consul_leader_name" \
            "Addr: $consul_leader_addr" \
            "ID: $consul_leader_id"
    }

    # Function to get the list of Consul servers via API and filter by role "consul"
    get_consul_servers() {
        servers=$(curl -s -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" "${CONSUL_HTTP_ADDR}/v1/agent/members" | jq -r '.[] | select(.Tags.role=="consul") | {Name, Addr, ID: .Tags.id}')
    }

    # Function to trigger a leadership transfer away from the current leader to a new server by ID
    trigger_leadership_transfer() {
        local new_leader_id=$1

        # Fetch the details of the new leader
        local new_leader_info
        new_leader_info=$(echo "$servers" | jq -r --arg id "$new_leader_id" '. | select(.ID == $id)')
        local new_leader_name
        new_leader_name=$(echo "$new_leader_info" | jq -r .Name)
        local new_leader_addr
        new_leader_addr=$(echo "$new_leader_info" | jq -r .Addr)

        print_msg "${script}: Transferring leadership:" \
            "$consul_leader_name *==> $new_leader_name" \
            "$consul_leader_addr *==> $new_leader_addr" \
            "$consul_leader_id   *==> $new_leader_id"

        [ -z "$consul_leader_id" ] && warn "${script}: Null new leader ID! Skipping, leader swap..." && return 0
        curl --request POST -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" "${CONSUL_HTTP_ADDR}/v1/operator/raft/transfer-leader?id=${new_leader_id}" >/dev/null 2>&1 || true
    }

    # Function to take a snapshot backup using Consul API
    take_snapshot() {
        info "${script}: Taking a snapshot backup *==> ${snapshot_file}"
        curl --show-error --silent --request GET -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" "${CONSUL_HTTP_ADDR}/v1/snapshot" --output "${snapshot_file}"
        if [ $? -eq 0 ]; then
            info "${script}: Snapshot backup saved to ${snapshot_file}"
        else
            info "${script}: Failed to take a snapshot backup."
        fi
    }

    # Function to restore from a snapshot backup
    restore_snapshot() {
        info "${script}: Restoring from snapshot backup..."
        curl --show-error --silent --request PUT -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" --data-binary @"${snapshot_file}" "${CONSUL_HTTP_ADDR}/v1/snapshot"
        if [ $? -eq 0 ]; then
            info "${script}: Restored successfully from ${snapshot_file}"
        else
            info "${script}: Failed to restore from snapshot."
        fi
    }

    # Loop for the specified duration to trigger leadership elections
    while [ $SECONDS -lt $end_time ]; do
        get_consul_leader

        if [ -z "$consul_leader_addr" ]; then
            local attempt=0
            while [ -z "$consul_leader_addr" ] && [ "$attempt" -lt 5 ]; do
                warn "${script}: [${attempt}/5]: Could not determine leader, reattempting in 2s..."
                attempt=$((attempt+1))
                sleep 2
                get_consul_leader
            done
            if [ "$attempt" -eq 5 ]; then
                err "${script}: Unable to find Consul leader, exiting..."
                return 1
            fi
        fi

        # Get the list of servers
        get_consul_servers

        # Extract server IDs and names (excluding the current leader)
        local available_servers
        available_servers=$(echo "$servers" | jq -r --arg leader "$consul_leader_addr" 'select(.Addr != $leader) | .ID')

        if [ -z "$available_servers" ]; then
            info "${script}: No available servers to transfer leadership to. Exiting..."
            return 1
        fi

        # Pick a random server ID for leadership transfer
        local random_server_id
        random_server_id=$(echo "$available_servers" | shuf -n 1)

        # Random interval based on the chaos interval flag
        interval=$((RANDOM % (chaos_max_interval - chaos_min_interval + 1) + chaos_min_interval))
        info "${script}: Next leadership transfer will be triggered in ${interval} seconds..."

        # Sleep for a random interval before triggering leadership transfer
        sleep $interval

        # Trigger leadership transfer
        trigger_leadership_transfer "$random_server_id"
        info "${script}: Leadership transfer triggered to server ID: ${random_server_id}"

        # If snapshot flag is enabled, randomly decide to take a snapshot or restore
        if [[ "$use_snapshots" == "true" ]]; then
            local snapshot_action
            snapshot_action=$((RANDOM % 2))
            if [[ $snapshot_action -eq 0 ]]; then
                take_snapshot
            else
                restore_snapshot
            fi
        fi
    done

    info "${script}: Leadership transfer process completed."
}

# Function to display usage
usage() {
    local exit_code="${1}"
    echo
    echo "${script}: Usage: $(basename "$0") --duration <duration-in-seconds> [--use-snapshots] [--chaos-interval <min-max>]"
    echo
    echo "Examples:"
    echo "  # Run for 60 seconds with snapshot functionality enabled"
    echo "  $(basename "$0") --duration 60 --use-snapshots"
    echo
    echo "  # Run for 120 seconds, random leadership transfer intervals between 10 and 30 seconds"
    echo "  $(basename "$0") --duration 120 --chaos-interval 10-30"
    echo
    echo "  # Run for 300 seconds with default chaos intervals (10-30) and no snapshots"
    echo "  $(basename "$0") --duration 300"
    exit $exit_code
}


# Parse optional flags
use_snapshots="false"
chaos_min_interval=10
chaos_max_interval=30
duration=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --consul-addr | -a )
            export CONSUL_HTTP_ADDR="$2"
            shift 2
            ;;
        --consul-token | -t )
            export CONSUL_HTTP_TOKEN="$2"
            shift 2
            ;;
        --duration)
            duration="$2"
            shift 2
            ;;
        --use-snapshots)
            use_snapshots="true"
            shift 1
            ;;
        --chaos-interval)
            if [[ "$2" =~ ^[0-9]+-[0-9]+$ ]]; then
                IFS='-' read -r chaos_min_interval chaos_max_interval <<< "$2"
            else
                err "${script}: Invalid format for --chaos-interval. Please use <min-max> format."
                exit
            fi
            shift 2
            ;;
        --help|-h|help)
              usage 0
              ;;
        *)
            warn "${script}: Invalid argument: $1"
            usage 2
            ;;
    esac
done

# Check if duration is provided
if [ -z "$duration" ]; then
    warn "${script}: Error: '--duration' parameter is required!"
    usage 2
fi

# Validate chaos interval values
if ((chaos_min_interval >= chaos_max_interval)); then
    err "${script}: Invalid chaos interval range. Ensure that min < max."
    exit
fi

# Run the election swap function for the user-specified duration
trigger_leadership_election "$duration" "$use_snapshots" "$chaos_min_interval" "$chaos_max_interval"
