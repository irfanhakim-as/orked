#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEP_PATH="${SOURCE_DIR}/../deps"

# source project files
source "${SOURCE_DIR}/utils.sh"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get private IPv4 addresses from user input
ip_addresses=($(get_values "private IPv4 address"))

# install metallb
# source: https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
kubectl apply -f "${DEP_PATH}/metallb/metallb-native.yaml"

# wait until no pods are pending
wait_for_pods metallb-system

# copy metallb-configuration.yaml to home directory
cp -f "${DEP_PATH}/metallb/metallb-configuration.yaml" ~

# replace {{ IPv4_RANGE }} in metallb-configuration.yaml
if [ "${#ip_addresses[@]}" -eq 1 ]; then
    ip_range="${ip_addresses[0]}"
else
    ip_range="${ip_addresses[0]}-${ip_addresses[-1]}"
fi
sed -i "s/{{ IPv4_RANGE }}/${ip_range}/g" ~/metallb-configuration.yaml

# apply metallb-configuration.yaml
kubectl apply -f ~/metallb-configuration.yaml