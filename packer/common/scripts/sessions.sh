#!/usr/bin/env bash
#
# File: sessions.sh
#
# Minimal reproducible script for TTL-based session lock testing:
#   1) Create a session with a TTL
#   2) Acquire a lock for that session
#   3) Wait past the TTL
#   4) Check if the session is (still) present
#   5) If it is, declare it "stuck"; otherwise, it's working properly
#
# Usage:
#   1) Make sure 'jq' is installed.
#   2) If using ACLs, set CONSUL_HTTP_TOKEN.
#   3) ./sessions.sh

set -euo pipefail

###############################################################################
# (Optional) Simple color definitions to make output easier to read
###############################################################################
BOLD="\e[1m"
RED="\e[91m"
GREEN="\e[32m"
YELLOW="\e[93m"
CYAN="\e[96m"
END_COLOR="\e[0m"

###############################################################################
# Configuration
###############################################################################
# Default Consul address
CONSUL_URL="${CONSUL_URL:-"${CONSUL_HTTP_ADDR:-http://127.0.0.1:8500}"}"

# KV key for demonstration
LOCK_KEY="service/stuck-session-test"

# Session name defaults to hostname
SESSION_NAME="${SESSION_NAME:-$(hostname)}"

# TTL (seconds) – how long the session should live if not renewed
TTL_SECONDS="${TTL_SECONDS:-10}"

# Wait time after TTL before checking session (e.g. TTL + LockDelay + buffer)
# Default: 2x TTL
WAIT_TIME="${WAIT_TIME:-$(( TTL_SECONDS * 2 ))}"

echo -e "${CYAN}${BOLD}Consul endpoint:${END_COLOR} $CONSUL_URL"
echo -e "${CYAN}${BOLD}Session name:   ${END_COLOR} $SESSION_NAME"
echo -e "${CYAN}${BOLD}Lock key:       ${END_COLOR} $LOCK_KEY"
echo -e "${CYAN}${BOLD}TTL seconds:    ${END_COLOR} $TTL_SECONDS"
echo -e "${CYAN}${BOLD}Wait time (s):  ${END_COLOR} $WAIT_TIME"
echo

###############################################################################
# 1. Create a TTL-based session
###############################################################################
echo -e "${BOLD}==> 1. Creating session (TTL=${TTL_SECONDS}s)...${END_COLOR}"
SESSION_ID=$(curl --fail --silent \
  --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN:-}" \
  --data "{\"Name\": \"$SESSION_NAME\", \"TTL\": \"${TTL_SECONDS}s\", \"Behavior\": \"release\"}" \
  --request PUT \
  "$CONSUL_URL/v1/session/create" | jq -r '.ID')

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
  echo -e "${RED}ERROR: Failed to create session!${END_COLOR}"
  exit 1
fi
echo -e "${GREEN}Session created. ID: $SESSION_ID${END_COLOR}"
echo

###############################################################################
# 2. Acquire the lock for that session
###############################################################################
echo -e "${BOLD}==> 2. Acquiring lock on $LOCK_KEY using session=$SESSION_ID...${END_COLOR}"
ACQUIRE_RESULT=$(curl --fail --silent \
  --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN:-}" \
  --data "{\"example\": \"no_renew\"}" \
  --request PUT \
  "$CONSUL_URL/v1/kv/$LOCK_KEY?acquire=$SESSION_ID")

if [ "$ACQUIRE_RESULT" = "true" ]; then
  echo -e "${GREEN}Lock acquired successfully.${END_COLOR}"
else
  echo -e "${YELLOW}Lock acquisition response:${END_COLOR} $ACQUIRE_RESULT"
  echo -e "${YELLOW}Another session likely holds the lock. Exiting.${END_COLOR}"
  exit 0
fi
echo

###############################################################################
# 3. Wait beyond the TTL
###############################################################################
echo -e "${BOLD}==> 3. Waiting ${WAIT_TIME}s (beyond the TTL) so Consul should invalidate the session...${END_COLOR}"
sleep "$WAIT_TIME"

###############################################################################
# 4. Check if the session is still present
###############################################################################
echo -e "${BOLD}==> 4. Checking if session $SESSION_ID is still present...${END_COLOR}"
ALL_SESSIONS=$(curl --fail --silent \
  --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN:-}" \
  "$CONSUL_URL/v1/session/list")

FOUND_SESSION=$(echo "$ALL_SESSIONS" | jq --arg sid "$SESSION_ID" '.[]?.ID | select(. == $sid)')

if [ -n "$FOUND_SESSION" ]; then
  echo -e "${RED}Session $SESSION_ID is still in /v1/session/list!${END_COLOR}"
  echo -e "${RED}That suggests a \"stuck session.\" (It was not invalidated by TTL expiration.)${END_COLOR}"
  exit 1
else
  echo -e "${GREEN}Session $SESSION_ID is not in /v1/session/list => it expired as expected.${END_COLOR}"
fi
echo

###############################################################################
# 5. Check if the KV lock is still bound
###############################################################################
echo -e "${BOLD}==> 5. Checking if $LOCK_KEY is still locked...${END_COLOR}"
KV_DATA=$(curl --fail --silent \
  --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN:-}" \
  "$CONSUL_URL/v1/kv/$LOCK_KEY")

# Parse the "Session" field if present
LOCKED_SESSION=$(echo "$KV_DATA" | jq -r '.[0].Session // empty' 2>/dev/null || true)

if [ -n "$LOCKED_SESSION" ]; then
  echo -e "${RED}KV $LOCK_KEY is still locked by session=$LOCKED_SESSION!${END_COLOR}"
  echo -e "${RED}But that session was expected to expire. This indicates a potential \"stuck\" lock.${END_COLOR}"
  exit 1
else
  echo -e "${GREEN}KV $LOCK_KEY is no longer locked => lock released as expected.${END_COLOR}"
fi
echo

###############################################################################
# Final outcome
###############################################################################
echo -e "${GREEN}${BOLD}SUCCESS: TTL-based session was invalidated, and the lock was released as expected.${END_COLOR}"
exit 0
