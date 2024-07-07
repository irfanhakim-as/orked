#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
SSH_PORT="${SSH_PORT:-"22"}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-"ed25519"}"; SSH_KEY_TYPE="${SSH_KEY_TYPE,,}"
SSH_KEY="${SSH_KEY:-"${HOME}/.ssh/id_${SSH_KEY_TYPE}"}"
PUBLIC_SSH_KEY="${PUBLIC_SSH_KEY:-"${SSH_KEY}.pub"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get hostnames of all kubernetes nodes
k8s_hostnames=($(get_values "hostname of kubernetes node"))

# generate ssh key if not exists
if ! [ -f "${SSH_KEY}" ]; then
    echo "Generating SSH key (${SSH_KEY_TYPE})"
    ssh-keygen -t "${SSH_KEY_TYPE}" -f "${SSH_KEY}" -N ""
else
    echo "SSH key already exists (${SSH_KEY})"
fi

# copy SSH key to each node
if [ -f "${PUBLIC_SSH_KEY}" ]; then
    for k8s_hostname in "${k8s_hostnames[@]}"; do
        echo "Copying public SSH key to ${SERVICE_USER}@${k8s_hostname}"
        ssh-copy-id -i "${PUBLIC_SSH_KEY}" -p "${SSH_PORT}" "${SERVICE_USER}@${k8s_hostname}"
    done
else
    echo "ERROR: public SSH key not found! (${PUBLIC_SSH_KEY})"
fi