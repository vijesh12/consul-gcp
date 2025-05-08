#bin/bash

for i in {1000..8000}
do
  consul services deregister "redis$i"
done

curl --request PUT \
  --data @deregister.json \
  http://127.0.0.1:8500/v1/agent/service/deregister/ingress-service