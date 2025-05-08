#!/usr/bin/env bash
set -euo pipefail
PROJECT="$1" # e.g. my-gcp-project
ZONE="$2"    # us-central1-a
FAMILY="$3"  # Packer image family

TEMPLATE="nomad-server"
MIG="nomad-server-mig"
HC_NAME="nomad-http-4646"

prompt_recreate() {
    local resource="$1"
    read -r -p "⚠️  $resource exists – delete & recreate? [y/N]: " ans
    [[ "${ans,,}" =~ ^y(es)?$ ]]
}

[ -z "$NOMAD_LICENSE" ] && echo "[ERROR]: \$NOMAD_LICENSE environment variable unset, set variable and re-run..."

# ── 0. Managed Instance Group (delete first if it locks the template) ──
if gcloud compute instance-groups managed describe "$MIG" \
    --project "$PROJECT" --zone "$ZONE" >/dev/null 2>&1; then
    if prompt_recreate "Managed instance group $MIG"; then
        echo "🗑  Deleting MIG $MIG ..."
        gcloud compute instance-groups managed delete "$MIG" \
            --project "$PROJECT" --zone "$ZONE" -q
    fi
fi

# ── 1. Health-check ─────────────────────────────────────────────
if gcloud compute health-checks describe "$HC_NAME" --project "$PROJECT" \
    >/dev/null 2>&1; then
    if prompt_recreate "Health-check $HC_NAME"; then
        gcloud compute health-checks delete "$HC_NAME" --project "$PROJECT" -q
    fi
fi
if ! gcloud compute health-checks describe "$HC_NAME" --project "$PROJECT" \
    >/dev/null 2>&1; then
    echo "🩺  Creating TCP health-check $HC_NAME (port 4646)…"
    gcloud compute health-checks create tcp "$HC_NAME" \
        --project "$PROJECT" \
        --port 4646 \
        --check-interval 15s \
        --timeout 5s \
        --healthy-threshold 2 \
        --unhealthy-threshold 2
fi

# ── 2. Instance template ───────────────────────────────────────
if gcloud compute instance-templates describe "$TEMPLATE" \
    --project "$PROJECT" >/dev/null 2>&1; then
    if prompt_recreate "Instance template $TEMPLATE"; then
        gcloud compute instance-templates delete "$TEMPLATE" --project "$PROJECT" -q
    fi
fi

if ! gcloud compute instance-templates describe "$TEMPLATE" \
    --project "$PROJECT" >/dev/null 2>&1; then
    echo "📑  Creating Nomad server template $TEMPLATE …"
    TMP_STARTUP=$(mktemp)
    cat >"$TMP_STARTUP" <<SCRIPT
#!/bin/bash
set -eu

NOMAD_LICENSE="$NOMAD_LICENSE"

cat >/etc/nomad.d/server.hcl <<EOF
data_dir = "/opt/nomad"
server {
  enabled          = true
  bootstrap_expect = 3
}
EOF

echo 'NOMAD_LICENSE=$NOMAD_LICENSE' >/etc/nomad.d/nomad.env

systemctl enable nomad && systemctl start nomad
SCRIPT
    chmod 0644 "$TMP_STARTUP"

    gcloud compute instance-templates create "$TEMPLATE" \
        --project "$PROJECT" \
        --machine-type n2-standard-16 \
        --boot-disk-size 200GB \
        --image-family "$FAMILY" \
        --image-project "$PROJECT" \
        --metadata-from-file startup-script="$TMP_STARTUP" \
        --tags nomad-server

    rm -f "$TMP_STARTUP"
fi

# ── 3. Managed Instance Group (create if missing) ──────────────
if ! gcloud compute instance-groups managed describe "$MIG" \
    --project "$PROJECT" --zone "$ZONE" >/dev/null 2>&1; then
    echo "🚀  Spinning up Nomad server MIG $MIG …"
    gcloud compute instance-groups managed create "$MIG" \
        --project "$PROJECT" \
        --zone "$ZONE" \
        --base-instance-name nomad-server \
        --size 3 \
        --template "$TEMPLATE" \
        --health-check "$HC_NAME" \
        --initial-delay 300
fi

echo "✅  Done."
