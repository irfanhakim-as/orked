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
METALLB_IP=(${METALLB_IP:-$(get_values "private IPv4 address")})

# env variables
env_variables=()

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get private IPv4 addresses from user input
ipv4_addresses=($(get_values "private IPv4 address"))

# get user confirmation
print_title "metallb"
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# validate number of IPv4 addresses
if [ "${#METALLB_IP[@]}" -lt 1 ]; then
    echo "ERROR: There must be at least 1 private IPv4 address"
    exit 1
fi

# install metallb
# source: https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
kubectl apply -f "${DEP_DIR}/metallb/metallb-native.yaml"

# wait until no pods are pending
wait_for_pods metallb-system

# copy metallb-configuration.yaml to home directory
cp -f "${DEP_DIR}/metallb/metallb-configuration.yaml" ~

# replace {{ IPv4_RANGE }} in metallb-configuration.yaml
if [ "${#METALLB_IP[@]}" -eq 1 ]; then
    ipv4_range="${METALLB_IP[0]}"
else
    ipv4_range="${METALLB_IP[0]}-${METALLB_IP[-1]}"
fi
sed -i "s/{{ IPv4_RANGE }}/${ipv4_range}/g" ~/metallb-configuration.yaml

# apply metallb-configuration.yaml
kubectl apply -f ~/metallb-configuration.yaml