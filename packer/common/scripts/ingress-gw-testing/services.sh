#!/bin/bash

# Register 100 different services with v1 tag
i=1
echo "Registering 100 services"
while [[ i -lt 101 ]]; do
  port=$(( i + 9000 ))
  curl \
      --request PUT \
      --data "{\"ID\": \"redis$i\",\"Name\": \"redis$i\",\"Meta\": {\"Version\": \"v1\"},\"Address\": \"127.0.0.1\",\"Port\": $port}" \
      http://127.0.0.1:8500/v1/agent/service/register
  i=$(( i + 1 ))
done


# Update each instance's tag every 1s interval
k=100
while :
do
  i=1
	sleep 2
	nextK=$(( k + 100 ))
	echo "Registering services $k to $nextK"
    while [[ i -lt 101 ]]; do
	    lastSvc=$(( k + i - 100 ))
		  svc=$(( k + i ))
	    port=$(( i + 9000 ))
      curl \
          --request PUT \
            --silent "http://127.0.0.1:8500/v1/agent/service/deregister/redis$lastSvc"
      curl \
        --request PUT \
          --data "{\"ID\": \"redis$svc\",\"Name\":\"redis$svc\",\"Address\":\"127.0.0.1\",\"Port\": $port}" \
            "http://127.0.0.1:8500/v1/agent/service/register"
		  i=$(( i + 1 ))
    done
	k=$(( k + 100 ))
done