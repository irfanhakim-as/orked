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

# print title
print_title "hostname resolution"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
MASTER_NODES=(${MASTER_NODES})
MASTER_NODES_IP=(${MASTER_NODES_IP})
WORKER_NODES=(${WORKER_NODES})
WORKER_NODES_IP=(${WORKER_NODES_IP})
LB_NODE="${LB_NODE}"
LB_NODE_IP="${LB_NODE_IP}"
# get IP-hostname pairs of all master nodes
get_kv_arrays MASTER_NODES MASTER_NODES_IP "hostname of master node"
# get IP-hostname pairs of all worker nodes
get_kv_arrays WORKER_NODES WORKER_NODES_IP "hostname of worker node"

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "MASTER_NODES"
    "MASTER_NODES_IP"
    "WORKER_NODES"
    "WORKER_NODES_IP"
)

# optional variables
opt_variables=(
    "LB_NODE"
    "LB_NODE_IP"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}" "${opt_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# determine if loadbalancer is supplied
if [ -n "${LB_NODE}" ] && [ -n "${LB_NODE_IP}" ]; then
    LB_ENABLED="true"
else
    LB_ENABLED="false"
fi

# combine node arrays
node_keys=("${MASTER_NODES[@]}" "${WORKER_NODES[@]}")
node_values=("${MASTER_NODES_IP[@]}" "${WORKER_NODES_IP[@]}")

# add loadbalancer to node arrays if enabled
if [ "${LB_ENABLED}" = "true" ]; then
    node_keys+=("${LB_NODE}")
    node_values+=("${LB_NODE_IP}")
fi

# determine cluster server endpoint
if [ "${LB_ENABLED}" = "true" ]; then
    SERVER_ENDPOINT="${LB_NODE}"
    SERVER_ENDPOINT_IP="${LB_NODE_IP}"
else
    SERVER_ENDPOINT="${MASTER_NODES[0]}"
    SERVER_ENDPOINT_IP="${MASTER_NODES_IP[0]}"
fi

#############################################################################################################

# update login node
# the login node must have name resolution to all nodes in the cluster
hostname="$(hostname)"
hosts_file="${hostname}-hosts.tmp"

echo "Updating login node: ${hostname}"

# download hosts file
run_with_sudo cat "/etc/hosts" > "${hosts_file}"

# iterate through all nodes
for ((index = 0; index < "${#node_keys[@]}"; index++)); do
    node_name="${node_keys[${index}]}"
    node_ip="${node_values[${index}]}"
    # modify hosts file
    update_hosts "${node_ip}" "${node_name}" "${hosts_file}"
done

# backup and update hosts file on node
run_with_sudo cp -f "/etc/hosts" "/etc/hosts.bak"
run_with_sudo cp -f "${hosts_file}" "/etc/hosts"
# remove temporary hosts file
rm "${hosts_file}"

#############################################################################################################

# update loadbalancer node
# the loadbalancer must have name resolution to all master nodes
if [ "${LB_ENABLED}" = "true" ]; then
    hostname="${LB_NODE}"
    ip="${LB_NODE_IP}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating loadbalancer: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file to include all master nodes
    for ((x = 0; x < "${#MASTER_NODES[@]}"; x++)); do
        h="${MASTER_NODES[${x}]}"
        i="${MASTER_NODES_IP[${x}]}"
        update_hosts "${i}" "${h}" "${hosts_file}"
    done
    # update hosts file on node
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
    # remove temporary hosts file
    rm "${hosts_file}"
fi

#############################################################################################################

# update worker nodes
# the worker nodes must have name resolution to the server endpoint
for ((index = 0; index < "${#WORKER_NODES[@]}"; index++)); do
    hostname="${WORKER_NODES[${index}]}"
    ip="${WORKER_NODES_IP[${index}]}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating worker: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file to include server endpoint
    update_hosts "${SERVER_ENDPOINT_IP}" "${SERVER_ENDPOINT}" "${hosts_file}"
    # update hosts file on node
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
    # remove temporary hosts file
    rm "${hosts_file}"
done

#############################################################################################################

# update master nodes
# the master nodes must have name resolution to all master nodes and loadbalancer (if enabled)
for ((index = 0; index < "${#MASTER_NODES[@]}"; index++)); do
    hostname="${MASTER_NODES[${index}]}"
    ip="${MASTER_NODES_IP[${index}]}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating master: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file to include loadbalancer if enabled
    if [ "${LB_ENABLED}" = "true" ]; then
        update_hosts "${SERVER_ENDPOINT_IP}" "${SERVER_ENDPOINT}" "${hosts_file}"
    fi
    # modify hosts file to include all master nodes
    for ((x = 0; x < "${#MASTER_NODES[@]}"; x++)); do
        h="${MASTER_NODES[${x}]}"
        i="${MASTER_NODES_IP[${x}]}"
        update_hosts "${i}" "${h}" "${hosts_file}"
    done
    # update hosts file on node
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
    # remove temporary hosts file
    rm "${hosts_file}"
done