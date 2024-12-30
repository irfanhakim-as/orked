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
print_title "rancher"

# variables
RANCHER_DOMAIN="${RANCHER_DOMAIN:-"$(get_data "Rancher domain")"}"
INGRESS_CLUSTERISSUER="${INGRESS_CLUSTERISSUER:-"$(get_data "Ingress cluster issuer" "letsencrypt-dns-prod")"}"

# env variables
env_variables=(
    "RANCHER_DOMAIN"
    "INGRESS_CLUSTERISSUER"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# install rancher
helm upgrade --install rancher rancher \
--repo https://releases.rancher.com/server-charts/stable \
--namespace cattle-system \
--create-namespace \
--version 2.8.5 \
--set hostname="${RANCHER_DOMAIN}" \
--set ingress.ingressClassName="nginx" \
--set ingress.tls.source="secret" \
--set ingress.extraAnnotations."cert-manager\.io/cluster-issuer"="${INGRESS_CLUSTERISSUER}" \
--set replicas=1 \
--wait

# wait until no pods are pending
wait_for_pods cattle-system

# get rancher deployment
kubectl get deployment rancher -n cattle-system -o wide

# get bootstrap password
echo "Visit the Rancher UI to finish setup:"
echo "https://${RANCHER_DOMAIN}/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')"