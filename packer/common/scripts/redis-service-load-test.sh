#!/bin/bash
# ----- Background -----
# Purpose: Consul Service Load test to prove memory leak present in Consul v1.11.7 -- see https://github.com/hashicorp/consul/pull/13869
# This script can be used to register 100 test (fake) redis services to Consul.
# No actual services are required.
# Once, the 100 services are added, the script will continue to run and modify the registered services to
#  simulate Consul Watch detection changes and cause an increase in Consul traffic.

register_redis_json=""
register_redis_json=$( cat <<-JSON
{
  "ID": "redis$i",
  "Name": "redis$i",
  "Meta": {
    "Version": "v1"
  },
  "Address": "127.0.0.1",
  "Port": "$port"
}
JSON
);

update_redis_tag_info=""
update_redis_tag_info=$( cat <<-JSON
{
  "ID": "redis$svc",
  "Name": "redis$svc",
  "Address": "127.0.0.1",
  "Port": $port
}
JSON
);

# Register 100 different services with v1 tag
i=1
echo "Registering 100 test services -- redis1 --> redis100"
while [[ i -lt 101 ]]; do
  port=$(( i + 9000 ))
  curl --request PUT \
        --data "{\"ID\": \"redis$i\",\"Name\": \"redis$i\",\"Meta\": {\"Version\": \"v1\"},\"Address\": \"127.0.0.1\",\"Port\": $port}" \
          "http://127.0.0.1:8500/v1/agent/service/register"
  i=$(( i + 1 ))
done


# Update each instance's tag every 1s interval
k=100
while :
do
  i=1
	sleep 2
	nextK=$(( k + 100 ))
	echo "Updating redis service $k to redis $nextK -- Press [ctrl + c] to terminate..."
    while [[ i -lt 101 ]]; do
	    lastSvc=$(( k + i - 100 ))
		  svc=$(( k + i ))
	    port=$(( i + 9000 ))
      curl --request PUT \
            --silent "http://127.0.0.1:8500/v1/agent/service/deregister/redis$lastSvc"
      curl --request PUT \
            --data "{\"ID\": \"redis$svc\",\"Name\":\"redis$svc\",\"Address\":\"127.0.0.1\",\"Port\": $port}" \
              "http://127.0.0.1:8500/v1/agent/service/register"
		  i=$(( i + 1 ))
    done
	k=$(( k + 100 ))
done