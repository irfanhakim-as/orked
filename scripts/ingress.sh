#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
DEP_DIR="${ROOT_DIR}/deps"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables (experimental)
NGINX_HTTP="${NGINX_HTTP:-"80"}"
NGINX_HTTPS="${NGINX_HTTPS:-"443"}"
NGINX_WEBHOOK="${NGINX_WEBHOOK:-"8443"}"

# env variables
env_variables=(
    "NGINX_HTTP"
    "NGINX_HTTPS"
    "NGINX_WEBHOOK"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
print_title "ingress"
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
--version v4.6.1 \
--set controller.containerPort.http="${NGINX_HTTP}" \
--set controller.containerPort.https="${NGINX_HTTPS}" \
--set controller.service.ports.http="${NGINX_HTTP}" \
--set controller.service.ports.https="${NGINX_HTTPS}" \
--set controller.admissionWebhooks.port="${NGINX_WEBHOOK}" \
--set controller.admissionWebhooks.service.servicePort="${NGINX_HTTPS}" \
--wait

# wait until no pods are pending
wait_for_pods ingress-nginx

# get ingress-nginx-controller service
kubectl get svc ingress-nginx-controller -n ingress-nginx