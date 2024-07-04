#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
port="${port:-"22"}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-"ed25519"}"; SSH_KEY_TYPE="${SSH_KEY_TYPE,,}"
PUBLIC_SSH_KEY="${PUBLIC_SSH_KEY:-"${HOME}/.ssh/id_${SSH_KEY_TYPE}.pub"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get service user account
service_user=$(get_data "service user account")

# get hostnames of all kubernetes nodes
k8s_hostnames=($(get_values "hostname of kubernetes node"))

# generate ssh key if not exists
if ! [ -f "${PUBLIC_SSH_KEY}" ]; then
    echo "Generating SSH key (${SSH_KEY_TYPE})"
    ssh-keygen -t "${SSH_KEY_TYPE}" -f "${PUBLIC_SSH_KEY}" -N ''
else
    echo "SSH key already exists (${PUBLIC_SSH_KEY})"
fi

# copy SSH key to each node
echo "Nodes:"
for k8s_hostname in "${k8s_hostnames[@]}"; do
    echo "Copying public SSH key to ${service_user}@${k8s_hostname}"
    ssh-copy-id -i ~/.ssh/id_ecdsa.pub -p "${port}" "${service_user}@${k8s_hostname}"
done