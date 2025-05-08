#!/usr/bin/env bash

set -e

num_of_requests="${1:-20}"


if ! [[ "$1" =~ -h|--help ]]; then
  duration="${2:-"3m"}"

  ip="${3:-"127.0.0.1"}"

  port="${4:-"9090"}"

  use_h2="${5:-false}"

  url="http://${ip}:${port}"
fi

# Check for command and number of namespaces
if [[ "$1" =~ -h|--help ]]; then
  echo ""
  echo "-----------------------------------------------------"
  echo "-------- aws hey load generator wrapper -------------"
  echo "-----------------------------------------------------"
  echo ""
  echo ""
  echo "Usage: "
  echo "    $0 [number_of_requests] [concurrency] [duration] [app_ip] [application_port] [use_htt2]"
  echo ""
  echo "Options:"
  echo "  [number_of_requests]: number of requests to generate to application"
  echo "  [concurrency]: number of concurrent requests to perform"
  echo "  [duration]: duration to run app service calls"
  echo "  [app_ip]: application host ip or dns name"
  echo "  [application_port]: application port of service"
  echo "  [use_htt2]: use http2 request calls vice http - Optional"
  exit 1
fi

# The following hey command generates HTTP requests with X (num_of_requests) requests
# with 50 (default) concurrent clients and lasts for 3 minutes.


if [[ ${use_h2} = true ]] || [[ ${use_h2} = 1 ]]; then
  echo "aws-hey: running http GET load-test with $num_of_requests requests to app on ${url} for $duration"
  hey -n "$num_of_requests" -z "$duration" -h2 -m "GET" -t 15 "${url}"
else
  echo "aws-hey: running http2 GET load-test with $num_of_requests requests to app on ${url} for $duration"
  hey -n "$num_of_requests" -z "$duration" -m "GET" -t 15 "${url}"
fi

echo "aws-hey: generated $num_of_requests requests to app on ${url} for $duration"