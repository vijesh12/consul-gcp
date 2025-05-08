#!/bin/bash
#cloud-config
#
# This script orchestrates the final cutover to 3 new servers in a 3-node Consul cluster.
# Steps:
#   1) Confirm we see 6 nodes in the Raft config (the 3 old + the 3 new).
#   2) Identify which are the new nodes, picking 1 new node to become the leader.
#   3) Transfer leadership to that new node.
#   4) Once leadership is confirmed, sequentially force-leave older nodes with prune=true.
#
# Assumptions / Prerequisites:
#   - This script is run on exactly ONE of the newly launched instances to avoid concurrency.
#   - 'curl', 'jq', and 'aws' CLI are installed, with credentials to describe instances.
#   - Each node name is "consul-<instance-id>" so we can parse instance IDs easily.
#   - The new servers are already joined to the cluster (i.e., the cluster sees 6 servers in Raft).
#   - $CONSUL_HTTP_ADDR is set (e.g. "http://10.0.0.2:8500") or defaulting to localhost.
#   - $CONSUL_HTTP_TOKEN has 'operator:write' privileges if ACLs are enabled.

set -euxo pipefail

#########################################
# 0) Basic Setup: local instance, etc.
#########################################

# AWS metadata and instance info
AWS_META_URL="http://169.254.169.254/latest/meta-data"
MY_INSTANCE_ID="$(curl -sS "$AWS_META_URL/instance-id")"
if [ -z "$MY_INSTANCE_ID" ]; then
  echo "[ERROR] Could not retrieve local instance ID."
  exit 1
fi

THIS_NODE_NAME="consul-${MY_INSTANCE_ID}"

: "${CONSUL_HTTP_ADDR:=http://127.0.0.1:8500}"
: "${CONSUL_HTTP_TOKEN:=}"

echo "[INFO] Running on node $THIS_NODE_NAME (instance: $MY_INSTANCE_ID)."

#########################################
# 1) Wait to see 6 servers in the Raft config
#########################################
# Because we want 3 old + 3 new before any old removal.

EXPECTED_TOTAL_SERVERS=6
MAX_WAIT=300  # adjust as needed
SLEEP_INTERVAL=5

echo "[INFO] Waiting up to $MAX_WAIT seconds to see $EXPECTED_TOTAL_SERVERS servers in Raft..."

start_time=$(date +%s)
while true; do
  RAFT_JSON="$(curl -sS --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    "$CONSUL_HTTP_ADDR/v1/operator/raft/configuration" || true)"

  # The servers are in .Servers[], each an object with fields {ID, Node, Address, Leader, Voter} etc.
  COUNT="$(echo "$RAFT_JSON" | jq -r '.Servers | length' 2>/dev/null || echo 0)"

  if [ "$COUNT" = "$EXPECTED_TOTAL_SERVERS" ]; then
    echo "[INFO] Found $COUNT servers in Raft config. Proceeding..."
    break
  fi

  now_time=$(date +%s)
  if [ $(( now_time - start_time )) -ge $MAX_WAIT ]; then
    echo "[ERROR] Timed out waiting for $EXPECTED_TOTAL_SERVERS servers in Raft. Current count: $COUNT"
    exit 1
  fi

  echo "[INFO] Currently see $COUNT servers; waiting..."
  sleep $SLEEP_INTERVAL
done

#########################################
# 2) Identify new vs. old servers
#########################################
# We'll define "new" as any node whose LaunchTime is >= the earliest new server's LaunchTime,
# or some logic that you prefer. For simplicity, let's get the LaunchTime for all 6, then
# we'll sort by LaunchTime, and assume the top 3 are the "new" ones.

SERVERS=$(echo "$RAFT_JSON" | jq -r '.Servers[] | .Node + "::" + .ID')

# Build an array of lines "consul-i-abc123::<RaftID>"
IFS=$'\n' read -r -d '' -a server_array <<< "$SERVERS" || true

declare -A LAUNCH_MAP=()  # map nodeName -> LaunchTime
declare -A ID_MAP=()      # map nodeName -> RaftID

# Gather LaunchTime for each node:
for entry in "${server_array[@]}"; do
  NODE="${entry%%::*}"
  RAFT_ID="${entry##*::}"

  # Expect node name like "consul-i-0abc123"
  if [[ ! "$NODE" =~ ^consul-(i-[0-9a-fA-F]+)$ ]]; then
    echo "[WARN] Node '$NODE' doesn't match 'consul-<instance_id>' pattern. Skipping."
    continue
  fi

  INST_ID="${BASH_REMATCH[1]}"
  ID_MAP["$NODE"]="$RAFT_ID"

  # Use AWS CLI to retrieve LaunchTime
  LAUNCH_TIME="$(aws ec2 describe-instances --instance-ids "$INST_ID" \
    --query 'Reservations[].Instances[].LaunchTime' --output text 2>/dev/null || true)"
  if [ -z "$LAUNCH_TIME" ] || [[ "$LAUNCH_TIME" == "None" ]]; then
    echo "[WARN] LaunchTime not found for instance '$INST_ID'."
    continue
  fi

  LAUNCH_MAP["$NODE"]="$LAUNCH_TIME"
  echo "[INFO] Node '$NODE' => instance '$INST_ID' => LaunchTime '$LAUNCH_TIME'"
done

# Next, sort the nodes by their LaunchTime so we can figure out which are newest.
# We'll build a list of "NODE LAUNCH_TIME" lines, sort them, and then pick the top 3 as new.
declare -a SORTED_NODES=()
while read -r line; do
  SORTED_NODES+=("$line")
done < <(
  for n in "${!LAUNCH_MAP[@]}"; do
    echo "$n ${LAUNCH_MAP[$n]}"
  done | sort -k2  # sorts by date string ascending (oldest first)
)

# The last 3 after sorting ascending are presumably your newest servers.
# If you want to handle ties or more robust logic, adapt as needed.
count_all="${#SORTED_NODES[@]}"
let new_start_index="$count_all - 3"

declare -a NEW_NODES=()
declare -a OLD_NODES=()

for i in "${!SORTED_NODES[@]}"; do
  line="${SORTED_NODES[$i]}"
  node_name="${line%% *}"   # everything up to first space
  if [ "$i" -ge "$new_start_index" ]; then
    # This is one of the newest 3
    NEW_NODES+=("$node_name")
  else
    OLD_NODES+=("$node_name")
  fi
done

echo "[INFO] Old nodes (to remove): ${OLD_NODES[@]:-none}"
echo "[INFO] New nodes: ${NEW_NODES[@]}"

#########################################
# 3) Transfer Leadership to one new node
#########################################
# Choose one new node to become leader. For example, pick the "lowest index" in NEW_NODES,
# or the local node if it is among the new ones, etc. We'll just pick the last one in the
# sorted list as "the newest" for demonstration.

NEW_LEADER="${NEW_NODES[-1]}"  # pick the last entry from NEW_NODES array
NEW_LEADER_ID="${ID_MAP["$NEW_LEADER"]}"

# If you want specifically the local node as leader (and you know you are in the new set),
# do something like:
# if [[ " ${NEW_NODES[*]} " =~ " $THIS_NODE_NAME " ]]; then
#   NEW_LEADER="$THIS_NODE_NAME"
#   NEW_LEADER_ID="${ID_MAP["$THIS_NODE_NAME"]}"
# fi

echo "[INFO] Transferring leadership to '$NEW_LEADER' (Raft ID: $NEW_LEADER_ID)..."

curl -sS --request POST \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  "$CONSUL_HTTP_ADDR/v1/operator/raft/transfer-leader?id=$NEW_LEADER_ID"

# Wait for the new node to appear as the actual leader:
LEADER_WAIT_MAX=60
leader_start=$(date +%s)
while true; do
  RAFT_JSON="$(curl -sS --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    "$CONSUL_HTTP_ADDR/v1/operator/raft/configuration" || true)"
  CURRENT_LEADER="$(echo "$RAFT_JSON" | jq -r '.Servers[] | select(.Leader == true) | .Node')"

  if [ "$CURRENT_LEADER" = "$NEW_LEADER" ]; then
    echo "[INFO] Leadership successfully transferred to $NEW_LEADER."
    break
  fi

  now_time=$(date +%s)
  if [ $(( now_time - leader_start )) -ge $LEADER_WAIT_MAX ]; then
    echo "[ERROR] Timed out waiting for leader transfer to $NEW_LEADER."
    exit 1
  fi
  echo "[INFO] Leader is currently '$CURRENT_LEADER'; waiting..."
  sleep 3
done

#########################################
# 4) Force-leave older servers (one by one)
#########################################

echo "[INFO] Removing old nodes sequentially..."

for OLD_NODE in "${OLD_NODES[@]}"; do
  echo "[INFO] Force-leaving old node with prune=true: $OLD_NODE"
  curl -sS --request PUT \
    --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    "$CONSUL_HTTP_ADDR/v1/agent/force-leave/$OLD_NODE?prune=true" \
    || echo "[WARN] Force-leave for node '$OLD_NODE' failed or timed out. Continuing..."

  # Wait a bit to let membership settle.
  sleep 5

  # Optionally re-check cluster membership and ensure we haven't lost quorum.
  # For a 3-node cluster, removing one node at a time is typically safe once we have 4+ nodes.
done

echo "[INFO] Done! The 3 new servers are in place, and the old servers have been removed."
exit 0
