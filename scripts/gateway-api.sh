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
print_title "gateway api"

# ================= DO NOT EDIT BEYOND THIS LINE =================

# install gateway api crds
# source: https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl apply --server-side --force-conflicts -f "$(get_dep_path "gateway-api/v1.6.1/standard-install.yaml")" || { echo "ERROR: Failed to apply Gateway API CRDs installation"; exit 1; }

# wait until the crds are established
kubectl wait --for=condition=Established --timeout=60s \
    crd/gatewayclasses.gateway.networking.k8s.io \
    crd/gateways.gateway.networking.k8s.io \
    crd/httproutes.gateway.networking.k8s.io \
    crd/referencegrants.gateway.networking.k8s.io \
    || { echo "ERROR: Gateway API CRDs are not established"; exit 1; }

# get gateway api crds
kubectl get crd | awk 'NR==1 || /gateway.networking.k8s.io/'
