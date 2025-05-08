#!/usr/bin/env bash
set -euo pipefail
PROJECT="$1"; REGION="$2"; CLUSTER="$3"; VERSION="$4" NODE_MACHINE="$5"

echo "🛠  Creating regional GKE cluster $CLUSTER ($VERSION) ..."
gcloud container clusters create "$CLUSTER" \
  --project "$PROJECT" \
  --region "$REGION" \
  --release-channel regular \
  --cluster-version "${VERSION}" \
  --num-nodes 3 \
  --machine-type "$NODE_MACHINE" \
  --enable-ip-alias \
  --tags consul-server \
  --workload-pool="${PROJECT}.svc.id.goog"

echo "⏳ Waiting for cluster credentials ..."
gcloud container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT"
