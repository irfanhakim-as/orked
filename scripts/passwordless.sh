#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SOURCE_DIR}/utils.sh"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
SSH_PORT="${SSH_PORT:-"22"}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-"ed25519"}"; SSH_KEY_TYPE="${SSH_KEY_TYPE,,}"
SSH_KEY="${SSH_KEY:-"${HOME}/.ssh/id_${SSH_KEY_TYPE}"}"
PUBLIC_SSH_KEY="${PUBLIC_SSH_KEY:-"${SSH_KEY}.pub"}"
KUBERNETES_NODES_IP=(${KUBERNETES_NODES_IP})
if [ "${#KUBERNETES_NODES_IP[@]}" -lt 1 ]; then
    MASTER_NODES_IP=(${MASTER_NODES_IP:-$(get_values "IPv4 address of master node")})
    WORKER_NODES_IP=(${WORKER_NODES_IP:-$(get_values "IPv4 address of worker node")})
    # get hostnames of all kubernetes nodes
    KUBERNETES_NODES_IP=("${MASTER_NODES_IP[@]}" "${WORKER_NODES_IP[@]}")
fi

# env variables
env_variables=(
    "SERVICE_USER"
    "SSH_PORT"
    "SSH_KEY_TYPE"
    "SSH_KEY"
    "PUBLIC_SSH_KEY"
    "KUBERNETES_NODES_IP"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
print_title "passwordless"
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# generate ssh key if not exists
if ! [ -f "${SSH_KEY}" ]; then
    echo "Generating SSH key (${SSH_KEY_TYPE})"
    ssh-keygen -t "${SSH_KEY_TYPE}" -f "${SSH_KEY}" -N ""
else
    echo "SSH key already exists (${SSH_KEY})"
fi

# copy SSH key to each node
if [ -f "${PUBLIC_SSH_KEY}" ]; then
    for node in "${KUBERNETES_NODES_IP[@]}"; do
        echo "Copying public SSH key to ${SERVICE_USER}@${node}"
        ssh-copy-id -i "${PUBLIC_SSH_KEY}" -p "${SSH_PORT}" "${SERVICE_USER}@${node}"
    done
else
    echo "ERROR: public SSH key not found! (${PUBLIC_SSH_KEY})"
fi