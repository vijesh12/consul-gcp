#!/usr/bin/env bash
set -euo pipefail
PROJECT="$1"
ZONE="$2"
FAMILY="$3"
CLUSTER="$4"

read -r -p "➡  GCP project (detected: $PROJECT) correct? [Y/n]: " CONFIRM
[[ "${CONFIRM,,}" == n* ]] && {
    echo "Aborted."
    exit 0
}

LB_IP="$(cat /tmp/consul_lb_ip 2>/dev/null || true)"
[[ -z "$LB_IP" ]] && {
    echo "❌  /tmp/consul_lb_ip missing"
    exit 1
}

HC_NAME="consul-tcp-8500"
TEMPLATE_NAME="consul-nomad-client"
MIG_NAME="consul-nomad-mig"
FW_RULE_SSH="allow-ssh-consul-nomad"
FW_RULE_IAP="allow-iap-ssh"
FW_RULE_NOMAD_RPC="allow-nomad-rpc"

prompt_recreate() {
    local resource="$1"
    local default="n" ans
    read -r -p "⚠️  $resource exists – delete & recreate? [y/N]: " ans
    [[ "${ans,,}" =~ ^y(es)?$ ]]
}

# ── 0. Health-check ─────────────────────────────────────────────
if gcloud compute health-checks describe "$HC_NAME" --project "$PROJECT" \
    --format='value(name)' >/dev/null 2>&1; then
    if prompt_recreate "Health-check $HC_NAME"; then
        gcloud compute health-checks delete "$HC_NAME" --project "$PROJECT" -q
    fi
fi
if ! gcloud compute health-checks describe "$HC_NAME" --project "$PROJECT" \
    --format='value(name)' >/dev/null 2>&1; then
    echo "🩺  Creating TCP health-check $HC_NAME ..."
    gcloud compute health-checks create tcp "$HC_NAME" \
        --project "$PROJECT" \
        --port 8500 \
        --check-interval 15s \
        --timeout 5s \
        --healthy-threshold 2 \
        --unhealthy-threshold 2
fi

# ── 1. Startup script temp file ────────────────────────────────
TMP_STARTUP=$(mktemp)
cat >"$TMP_STARTUP" <<EOF
#!/bin/bash
set -e
CONSUL_LB="$LB_IP"

cat >/etc/consul.d/client.hcl <<HCL
datacenter  = "idig-prod-us-east1"
data_dir    = "/opt/consul"
client_addr = "0.0.0.0"
bind_addr   = "{{ GetInterfaceIP \"ens4\" }}"
retry_join  = ["\$CONSUL_LB"]
auto_encrypt { tls = true }
acl { enabled = true tokens { default = "root" } }
HCL

systemctl enable consul && systemctl start consul

cat >/etc/nomad.d/client.hcl <<HCL
data_dir = "/opt/nomad"
client   { enabled = true }
consul   {
    address = "127.0.0.1:8500"
    token = "root"
    client_auto_join = true
    server_auto_join  = true
}
HCL

systemctl enable nomad && systemctl start nomad
EOF
chmod 0644 "$TMP_STARTUP"

# ── 2. Instance template (plus MIG dependency handling) ─────────
template_exists() {
    gcloud compute instance-templates list --project "$PROJECT" \
        --filter="name=$TEMPLATE_NAME" --format='value(name)' | grep -q .
}
mig_exists() {
    gcloud compute instance-groups managed list --project "$PROJECT" \
        --zones "$ZONE" --filter="name=$MIG_NAME" --format='value(name)' | grep -q .
}

# a) Delete-and-recreate template if requested
if template_exists; then
    if prompt_recreate "Instance template $TEMPLATE_NAME"; then
        # If MIG uses this template, delete MIG first (with confirmation)
        if mig_exists; then
            echo "⚠️  $MIG_NAME currently uses $TEMPLATE_NAME."
            if prompt_recreate "Delete MIG $MIG_NAME first"; then
                gcloud compute instance-groups managed delete "$MIG_NAME" \
                    --project "$PROJECT" --zone "$ZONE" -q
            else
                echo "➡  Skipping template recreation because MIG still uses it."
            fi
        fi
        # Delete template if the dependency is gone
        if ! mig_exists && template_exists; then
            gcloud compute instance-templates delete "$TEMPLATE_NAME" \
                --project "$PROJECT" -q
        fi
    fi
fi

# b) Create template if it no longer exists
if ! template_exists; then
    echo "📑  Creating instance template $TEMPLATE_NAME ..."
    gcloud compute instance-templates create "$TEMPLATE_NAME" \
        --project "$PROJECT" \
        --machine-type n2-standard-16 \
        --boot-disk-size 200GB \
        --image-family "$FAMILY" \
        --image-project "$PROJECT" \
        --metadata-from-file startup-script="$TMP_STARTUP" \
        --tags consul-client,nomad-client
fi
rm -f "$TMP_STARTUP"
# ── 3. Firewall rules (SSH + IAP) ──────────────────────────────
make_fw_rule() {
    local name="$1" source="$2"
    if gcloud compute firewall-rules list --project "$PROJECT" \
        --filter="name=$name" --format='value(name)' | grep -q .; then
        if prompt_recreate "Firewall rule $name"; then
            gcloud compute firewall-rules delete "$name" --project "$PROJECT" -q
        fi
    fi
    if ! gcloud compute firewall-rules list --project "$PROJECT" \
        --filter="name=$name" --format='value(name)' | grep -q .; then
        echo "🔥  Creating firewall rule $name ..."
        gcloud compute firewall-rules create "$name" \
            --project "$PROJECT" \
            --network default \
            --direction INGRESS \
            --action ALLOW \
            --rules tcp:22 \
            --source-ranges "$source" \
            --target-tags consul-client,nomad-client
    fi
}

MY_IP=$(curl -s https://ipinfo.io/ip)
make_fw_rule "$FW_RULE_SSH" "${MY_IP}/32"
make_fw_rule "$FW_RULE_IAP" "35.235.240.0/20"

## Create Nomad RPC allow rule between clients and servers
if gcloud compute firewall-rules list --project "$PROJECT" --filter="name=$FW_RULE_NOMAD_RPC" --format='value(name)' | grep -q .; then
    if prompt_recreate "Firewall rule $FW_RULE_NOMAD_RPC"; then
        gcloud compute firewall-rules delete "$FW_RULE_NOMAD_RPC" --project "$PROJECT" -q
    fi
fi
if ! gcloud compute firewall-rules list --project "$PROJECT" --filter="name=$FW_RULE_NOMAD_RPC" --format='value(name)' | grep -q .; then
    echo "🔥 Creating firewall rule $FW_RULE_NOMAD_RPC ..."
    gcloud compute firewall-rules create allow-nomad-rpc \
      --project "$PROJECT" \
      --direction INGRESS \
      --network default \
      --action ALLOW \
      --source-tags nomad-client,nomad-server \
      --target-tags nomad-client,nomad-server \
      --rules tcp:4647
fi
# ── 4. Managed Instance Group ───────────────────────────────────
if mig_exists; then
    if prompt_recreate "Managed instance group $MIG_NAME"; then
        gcloud compute instance-groups managed delete "$MIG_NAME" \
            --project "$PROJECT" --zone "$ZONE" -q
    fi
fi
if ! mig_exists; then
    echo "🚀  Creating managed instance group $MIG_NAME ..."
    gcloud compute instance-groups managed create "$MIG_NAME" \
        --project "$PROJECT" \
        --zone "$ZONE" \
        --base-instance-name consul-nomad \
        --size 3 \
        --template "$TEMPLATE_NAME" \
        --health-check "$HC_NAME" \
        --initial-delay 300
fi
