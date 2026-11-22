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
print_title "gateway"

# variables
GATEWAY_IP="${GATEWAY_IP:-"$(get_data "Gateway private IPv4 address")"}"
GATEWAY_DOMAINS=(${GATEWAY_DOMAINS:-$(get_values "Gateway domain")})
GATEWAY_CLUSTERISSUER="${GATEWAY_CLUSTERISSUER:-"$(get_data "Gateway cluster issuer" "letsencrypt-dns-prod")"}"

# env variables
env_variables=(
    "GATEWAY_IP"
    "GATEWAY_DOMAINS"
    "GATEWAY_CLUSTERISSUER"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# validate number of domains
if [ "${#GATEWAY_DOMAINS[@]}" -lt 1 ]; then
    echo "ERROR: There must be at least 1 domain"; exit 1
fi

# copy gateway manifests to home directory
cp -f "$(get_dep_path "envoy-gateway/gatewayclass.yaml")" "$(get_dep_path "envoy-gateway/envoyproxy.yaml")" "$(get_dep_path "envoy-gateway/gateway.yaml")" "$(get_dep_path "envoy-gateway/http-redirect.yaml")" ~

# replace {{ GATEWAY_IP }} in envoyproxy.yaml
sed -i "s/{{ GATEWAY_IP }}/${GATEWAY_IP}/g" ~/envoyproxy.yaml

# replace {{ GATEWAY_CLUSTERISSUER }} in gateway.yaml
sed -i "s/{{ GATEWAY_CLUSTERISSUER }}/${GATEWAY_CLUSTERISSUER}/g" ~/gateway.yaml

# add a wildcard https listener per domain to gateway.yaml
if ! file_ends_with_newline ~/gateway.yaml; then
    echo >> ~/gateway.yaml
fi
for domain in "${GATEWAY_DOMAINS[@]}"; do
    name="${domain//./-}"
    cat >> ~/gateway.yaml <<EOT
  - name: https-${name}
    protocol: HTTPS
    port: 443
    hostname: "*.${domain}"
    tls:
      mode: Terminate
      certificateRefs:
      - name: wildcard-${name}-tls
    allowedRoutes:
      namespaces:
        from: All
EOT
done

# apply gateway manifests
kubectl apply -f ~/gatewayclass.yaml -f ~/envoyproxy.yaml -f ~/gateway.yaml -f ~/http-redirect.yaml || { echo "ERROR: Failed to apply gateway manifests"; exit 1; }

# wait until the gateway is programmed
kubectl wait --for=condition=Programmed --timeout=600s gateway/envoy-gateway -n envoy-gateway-system || { echo "ERROR: Gateway is not programmed"; exit 1; }

# wait until no pods are pending
wait_for_pods envoy-gateway-system

# get gateway
kubectl get gateway envoy-gateway -n envoy-gateway-system

# get gateway certificates
kubectl get certificate -n envoy-gateway-system
