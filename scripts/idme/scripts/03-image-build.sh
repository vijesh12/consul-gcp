#!/usr/bin/env bash
set -euo pipefail
PROJECT="$1"; REGION="$2"; IMG_NAME="$3"; FAMILY="$4"
NOMAD_VER="$5"; CONSUL_VER="$6"

echo "📸 Building GCE image $IMG_NAME (family $FAMILY) with Packer ..."
packer build -var gcp_project_id="$(gcloud config get-value project)" ../../../packer/ami/hashistack-ubuntu.pkr.hcl
