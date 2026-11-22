#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
DEP_DIR="${ROOT_DIR}/deps"
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SOURCE_DIR}/utils.sh"

# print title
print_title "envoy gateway"

# ================= DO NOT EDIT BEYOND THIS LINE =================

# check gateway api crds are installed
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || { echo "ERROR: Gateway API CRDs are not installed"; exit 1; }

# install envoy gateway crds
# source: helm template eg-crds oci://docker.io/envoyproxy/gateway-crds-helm --version v1.10.0 --set crds.envoyGateway.enabled=true
kubectl apply --server-side --force-conflicts -f "$(get_dep_path "envoy-gateway/v1.10.0/envoy-gateway-crds.yaml")" || { echo "ERROR: Failed to apply Envoy Gateway CRDs installation"; exit 1; }

# wait until the crds are established
kubectl wait --for=condition=Established --timeout=60s \
    crd/backends.gateway.envoyproxy.io \
    crd/backendtrafficpolicies.gateway.envoyproxy.io \
    crd/clienttrafficpolicies.gateway.envoyproxy.io \
    crd/envoyextensionpolicies.gateway.envoyproxy.io \
    crd/envoypatchpolicies.gateway.envoyproxy.io \
    crd/envoyproxies.gateway.envoyproxy.io \
    crd/httproutefilters.gateway.envoyproxy.io \
    crd/securitypolicies.gateway.envoyproxy.io \
    || { echo "ERROR: Envoy Gateway CRDs are not established"; exit 1; }

# install envoy gateway
helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
    --namespace envoy-gateway-system \
    --create-namespace \
    --version v1.10.0 \
    --set crds.enabled=false \
    --wait || { echo "ERROR: Failed to apply Envoy Gateway installation"; exit 1; }

# wait until no pods are pending
wait_for_pods envoy-gateway-system "envoy-gateway-[a-z0-9]*-[a-z0-9]*$"

# get envoy gateway deployment
kubectl get deployment envoy-gateway -n envoy-gateway-system
