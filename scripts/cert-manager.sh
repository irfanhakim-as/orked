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

# variables
CF_EMAIL="${CF_EMAIL:-"$(get_data "Cloudflare user email")"}"
CF_API_KEY="${CF_API_KEY:-"$(get_data "Cloudflare API key")"}"

# env variables
env_variables=(
    "CF_EMAIL"
    "CF_API_KEY"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
print_title "cert-manager"
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# add helm repo
if ! helm repo list 2>&1 | grep -q "jetstack"; then
    helm repo add jetstack https://charts.jetstack.io
fi

# update helm repo
helm repo update jetstack

# install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.11.0 --set installCRDs=true --wait

# wait until no pods are pending
wait_for_pods cert-manager

# patch the cert-manager deployment to add dnsConfig: options: - name: ndots value: "1"
kubectl patch deployment cert-manager -n cert-manager --type=json -p='[
    {
        "op": "add",
        "path": "/spec/template/spec/dnsConfig",
        "value": {
            "options": [
                {
                    "name": "ndots",
                    "value": "1"
                }
            ]
        }
    }
]'

# copy cloudflare secrets to home directory
cp -f "${DEP_DIR}/cert-manager/cloudflare-api-key-secret.yaml" "${DEP_DIR}/cert-manager/cloudflare-api-token-secret.yaml" ~

# add cloudflare api key to cloudflare secrets
sed -i "s/{{ CLOUDFLARE_API_KEY }}/${CF_API_KEY}/g" ~/cloudflare-api-key-secret.yaml
sed -i "s/{{ CLOUDFLARE_API_KEY }}/${CF_API_KEY}/g" ~/cloudflare-api-token-secret.yaml

# deploy cloudflare secrets
kubectl apply -f ~/cloudflare-api-key-secret.yaml -f ~/cloudflare-api-token-secret.yaml -n cert-manager

# copy letsencrypt validation manifests to home directory
cp -f "${DEP_DIR}/cert-manager/letsencrypt-dns-validation.yaml" "${DEP_DIR}/cert-manager/letsencrypt-http-validation.yaml" ~

# add cloudflare user email to letsencrypt validation manifests
sed -i "s/{{ CLOUDFLARE_USER_EMAIL }}/${CF_EMAIL}/g" ~/letsencrypt-dns-validation.yaml
sed -i "s/{{ CLOUDFLARE_USER_EMAIL }}/${CF_EMAIL}/g" ~/letsencrypt-http-validation.yaml

# deploy letsencrypt cluster issuers
kubectl apply -f ~/letsencrypt-dns-validation.yaml -f ~/letsencrypt-http-validation.yaml -n cert-manager

# get letsencrypt cluster issuers
kubectl get clusterissuer -o wide | awk 'NR==1 || /letsencrypt/'