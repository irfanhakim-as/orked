#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEP_PATH="${SOURCE_DIR}/../deps"

# source project files
source "${SOURCE_DIR}/utils.sh"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get private IPv4 addresses from user input
ipv4_addresses=($(get_values "private IPv4 address"))

# install metallb
# source: https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
kubectl apply -f "${DEP_PATH}/metallb/metallb-native.yaml"

# wait until no pods are pending
wait_for_pods metallb-system

# copy metallb-configuration.yaml to home directory
cp -f "${DEP_PATH}/metallb/metallb-configuration.yaml" ~

# replace {{ IPv4_RANGE }} in metallb-configuration.yaml
if [ "${#ipv4_addresses[@]}" -eq 1 ]; then
    ipv4_range="${ipv4_addresses[0]}"
else
    ipv4_range="${ipv4_addresses[0]}-${ipv4_addresses[-1]}"
fi
sed -i "s/{{ IPv4_RANGE }}/${ipv4_range}/g" ~/metallb-configuration.yaml

# apply metallb-configuration.yaml
kubectl apply -f ~/metallb-configuration.yaml