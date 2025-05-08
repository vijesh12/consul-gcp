#!/bin/bash

set -euo pipefail

prune_members() {
  local members=()

 read -r -a members <<< "$(consul members | grep "left" | awk '{print $1}' | tr '\n' ' ')"
  # do the thing
  echo "**** Starting serf_lan pool member pruning"
  for member in "${members[@]}"; do
    echo "pruning ${member}"
    consul force-leave -prune "${member}"
  done

  echo "**** consul members serf lan list pruned"
}

prune_wan_members() {
  local members=()

 read -r -a members <<< "$(consul members -wan | grep "left" | awk '{print $1}' | tr '\n' ' ')"
  # do the thing
  echo "**** Starting serf_wan pool member pruning"
  for member in "${members[@]}"; do
    echo "pruning ${member}"
    consul force-leave -wan -prune "${member}"
  done

  echo "**** consul members serf lan list pruned"
}

prune_members
prune_wan_members