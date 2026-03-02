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
print_title "ingress"

# variables (experimental)
NGINX_HTTP="${NGINX_HTTP:-"80"}"
NGINX_HTTPS="${NGINX_HTTPS:-"443"}"
# NGINX_WEBHOOK="${NGINX_WEBHOOK:-"8443"}"
NGINX_GEOIP="${NGINX_GEOIP:-"$(get_bool "enable GeoIP2 geofiltering")"}"; echo

# env variables
env_variables=(
    "NGINX_HTTP"
    "NGINX_HTTPS"
    # "NGINX_WEBHOOK"
    "NGINX_GEOIP"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# install nginx ingress
helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --version 4.14.0 \
    --set controller.service.ports.http="${NGINX_HTTP}" \
    --set controller.service.ports.https="${NGINX_HTTPS}" \
    --set admissionWebhooks.service.servicePort="${NGINX_HTTPS}" \
    $([ "${NGINX_GEOIP}" == "true" ] && echo "-f ${DEP_DIR}/ingress/geoip-values.yaml") \
    --wait || { echo "ERROR: Failed to apply ingress-nginx installation"; exit 1; }

# wait until no pods are pending
wait_for_pods ingress-nginx

# get ingress-nginx-controller service
kubectl get svc ingress-nginx-controller -n ingress-nginx