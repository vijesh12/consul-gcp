#!/bin/bash

# Register 100 different services with v1 tag
i=0
while [ $i -lt 96 ]
echo "Scraping Metrics Endpoints -- Pull $i of 96"
do
curl http://127.0.0.1:8500/v1/agent/metrics?pretty > ~/metrics/metrics-initial-$i.json
i=$(( $i + 1 ))
# Sleep 30 Minutes
sleep 1800
done

curl \
    --silent \
    --remote-name \
    https://releases.hashicorp.com/hcdiag/0.1.1/hcdiag_0.3.1_linux_amd64.zip