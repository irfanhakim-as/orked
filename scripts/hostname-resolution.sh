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

# ================= DO NOT EDIT BEYOND THIS LINE =================

# declare -A master_dns_map
# get_kv_pairs master_dns_map "IP of master node"

# declare -A worker_dns_map
# get_kv_pairs worker_dns_map "IP of worker node"

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# combine node arrays
node_keys=("${MASTER_NODES[@]}" "${WORKER_NODES[@]}")
node_values=("${MASTER_NODES_IP[@]}" "${WORKER_NODES_IP[@]}")
# sort and combine node keys
# master_keys=($(echo "${!master_dns_map[@]}" | tr " " "\n" | sort))
# worker_keys=($(echo "${!worker_dns_map[@]}" | tr " " "\n" | sort))
# node_keys=("${master_keys[@]}" "${worker_keys[@]}")

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
# for node_ip in "${node_keys[@]}"; do
#     node_name="${master_dns_map[${node_ip}]:-${worker_dns_map[${node_ip}]}}"
#     # modify hosts file
#     update_hosts "${node_ip}" "${node_name}" "${hosts_file}"
# done

# backup and update hosts file on node
run_with_sudo cp -f "/etc/hosts" "/etc/hosts.bak"
run_with_sudo cp -f "${hosts_file}" "/etc/hosts"
# remove temporary hosts file
rm "${hosts_file}"

# update worker nodes
# the worker nodes must have name resolution to the primary master node
for ((index = 0; index < "${#WORKER_NODES[@]}"; index++)); do
    hostname="${WORKER_NODES[${index}]}"
    ip="${WORKER_NODES_IP[${index}]}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating worker: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file
    update_hosts "${MASTER_NODES_IP[0]}" "${MASTER_NODES[0]}" "${hosts_file}"
    # update hosts file on node
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
    # remove temporary hosts file
    rm "${hosts_file}"
done
# for ip in "${worker_keys[@]}"; do
#     hostname="${worker_dns_map[${ip}]}"
#     hosts_file="${hostname}-hosts.tmp"

#     echo "Updating worker: ${hostname} (${ip})"

#     # download hosts file
#     ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
#     # modify hosts file
#     update_hosts "${master_keys[0]}" "${master_dns_map[${master_keys[0]}]}" "${hosts_file}"
#     # update hosts file on node
#     ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
#     # remove temporary hosts file
#     rm "${hosts_file}"
# done

# update master nodes
# the master nodes must have name resolution to all master nodes
for ((index = 0; index < "${#MASTER_NODES[@]}"; index++)); do
    hostname="${MASTER_NODES[${index}]}"
    ip="${MASTER_NODES_IP[${index}]}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating master: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file
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
# for ip in "${master_keys[@]}"; do
#     hostname="${master_dns_map[${ip}]}"
#     hosts_file="${hostname}-hosts.tmp"

#     echo "Updating master: ${hostname} (${ip})"

#     # download hosts file
#     ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
#     # modify hosts file
#     for i in "${master_keys[@]}"; do
#         h="${master_dns_map[${i}]}"
#         update_hosts "${i}" "${h}" "${hosts_file}"
#     done
#     # update hosts file on node
#     ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
#     # remove temporary hosts file
#     rm "${hosts_file}"
# done