#!/bin/bash

# get private IPv4 addresses from user input
ip_addresses=($(bash ./utils.sh --get-values "private IPv4 address"))

# install metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml

# wait until no pods are pending
bash ./utils.sh --wait-for-pods metallb-system

# copy metallb-configuration.yaml to home directory
cp -f ../manifests/metallb-configuration.yaml ~

# replace {{ IPv4_RANGE }} in metallb-configuration.yaml
if [ "${#ip_addresses[@]}" -eq 1 ]; then
    ip_range="${ip_addresses[0]}"
else
    ip_range="${ip_addresses[0]}-${ip_addresses[-1]}"
fi
sed -i "s/{{ IPv4_RANGE }}/${ip_range}/g" ~/metallb-configuration.yaml

# apply metallb-configuration.yaml
kubectl apply -f ~/metallb-configuration.yaml