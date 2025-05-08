#!/usr/bin/env bash

set -euo pipefail

eval "$(cat ../../utils/formatting.env)"
eval "$(cat ../../utils/logging.sh)"

CLUSTER="$1"; REGION="$2"; CONSUL_K8S_VER="$3"; CONSUL_DP_VER="$4" CONSUL_VER="$5"
echo "🔌 Connecting kubectl to $CLUSTER ..."
gcloud container clusters get-credentials "$CLUSTER" --region "$REGION"

export CONTEXT; CONTEXT="$(kubectl config get-contexts --no-headers --output=name | grep consul-cluster)"
export HELM_VALUES=values.yaml

enableHelmRepo() {
    info "install-consul: Clearing helm repository cache from $HOME/Library/Caches/helm/repository"
    rm -rf "${HOME}"/Library/Caches/helm/repository/* || true
    sleep 2
    info "install-consul: Adding/updating https://helm.releases.hashicorp.com Helm repository"
    helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
}

# Define a function to check if a Helm release is installed
is_helm_release_installed() {
    local release_name="$1"
    local namespace="$2"
    local cluster_context="$3"

    # Run 'helm list' and check if the release exists in the specified namespace
    if helm list -n "$namespace" --kube-context "$cluster_context" | grep -qE "^$release_name\s"; then
        return 0 # Return 0 if the release is installed
    else
        return 1 # Return 1 if the release is not installed
    fi
}

install_confirm() {
    local helm_release="${1}"
    local namespace="${2}"
    local cluster_context="${3}"
    local response

    if is_helm_release_installed "${helm_release}" "${namespace}" "${cluster_context}"; then
        prompt "install-consul: Previous release installed for '${helm_release}' - Run reinstall? (y/n)"
        read -r response </dev/tty
        response="$(echo "$response" | tr '[:upper:]' '[:lower:]')"
    else
        response=yes
    fi
    [[ "$response" =~ yes|y ]] && return 0
    [[ "$response" =~ no|n ]] && return 1
}

create_namespace() {
    local cluster_context="$1"
    local namespace="$2"

    info "install-consul: Creating/verifying namespace $namespace | $cluster_context"
    kubectl --context "$cluster_context" create namespace "$namespace" >/dev/null 2>&1 || true
}

create_secret() {
    local cluster_context="$1"
    local namespace="$2"
    local secret_name="$3"
    local key="$4"

    info "install-consul: Creating/verifying generic secret $secret_name in ns $namespace | $cluster_context"
    kubectl --context "$cluster_context" -n "$namespace" create secret generic "$secret_name" --from-literal="key=$key" >/dev/null 2>&1 || true
}

[ -z "$CONSUL_LICENSE" ] && err "CONSUL_LICENSE env var unset!! Please set value to valid license key and re-run..." && exit

create_namespace "$CONTEXT" consul
create_secret "$CONTEXT" consul license "${CONSUL_LICENSE}"
create_secret "$CONTEXT" consul bootstrap-token root

echo "📦 Installing Consul Helm chart $CONSUL_K8S_VER (image $CONSUL_VER) ..."
enableHelmRepo
helm upgrade \
    --install consul hashicorp/consul \
    --create-namespace \
    --namespace consul \
    --version "$CONSUL_K8S_VER" \
    --values "$HELM_VALUES" \
    --set global.image="hashicorp/consul-enterprise:${CONSUL_VER}" \
    --set global.imageK8S="hashicorp/consul-k8s-control-plane:${CONSUL_K8S_VER}" \
    --set global.imageConsulDataplane="hashicorp/consul-dataplane:${CONSUL_DP_VER}" \
    --wait


echo "🌐 Fetching LB IP ..."
LB_IP="$(kubectl -n consul get svc consul-expose-servers -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
[[ -z "$LB_IP" ]] && { echo "❌ LoadBalancer IP not ready"; exit 1; }
echo "✅ Consul servers ready at $LB_IP:8500"
echo "$LB_IP" > /tmp/consul_lb_ip           # pass to later scripts
