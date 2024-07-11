#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
SCRIPT_DIR="${ROOT_DIR}/scripts"

# source project files
source "${SCRIPT_DIR}/utils.sh"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get IP-hostname pairs of all master nodes
declare -A master_dns_map
get_kv_pairs master_dns_map "IP of master node"

# get IP-hostname pairs of all worker nodes
declare -A worker_dns_map
get_kv_pairs worker_dns_map "IP of worker node"

# get user confirmation
print_title "hostname resolution"
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# sort and combine node keys
master_keys=($(echo "${!master_dns_map[@]}" | tr " " "\n" | sort))
worker_keys=($(echo "${!worker_dns_map[@]}" | tr " " "\n" | sort))
node_keys=("${master_keys[@]}" "${worker_keys[@]}")

# update login node
hostname="$(hostname)"
hosts_file="${hostname}-hosts.tmp"

echo "Updating login node: ${hostname}"

# download hosts file
run_with_sudo cat "/etc/hosts" > "${hosts_file}"

# iterate through all nodes
for node_ip in "${node_keys[@]}"; do
    node_name="${master_dns_map[${node_ip}]:-${worker_dns_map[${node_ip}]}}"
    # modify hosts file
    update_hosts "${node_ip}" "${node_name}" "${hosts_file}"
done

# backup and update hosts file on node
run_with_sudo cp -f "/etc/hosts" "/etc/hosts.bak"
run_with_sudo cp -f "${hosts_file}" "/etc/hosts"
# remove temporary hosts file
rm "${hosts_file}"

# iterate through worker nodes
for ip in "${worker_keys[@]}"; do
    hostname="${worker_dns_map[${ip}]}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating worker: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file
    update_hosts "${master_keys[0]}" "${master_dns_map[${master_keys[0]}]}" "${hosts_file}"
    # update hosts file on node
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
    # remove temporary hosts file
    rm "${hosts_file}"
done

# iterate through master nodes
for ip in "${master_keys[@]}"; do
    hostname="${master_dns_map[${ip}]}"
    hosts_file="${hostname}-hosts.tmp"

    echo "Updating master: ${hostname} (${ip})"

    # download hosts file
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/hosts\"'" > "${hosts_file}"
    # modify hosts file
    for i in "${master_keys[@]}"; do
        h="${master_dns_map[${i}]}"
        update_hosts "${i}" "${h}" "${hosts_file}"
    done
    # update hosts file on node
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cp \"/etc/hosts\" \"/etc/hosts.bak\" && echo \"$(cat ${hosts_file})\" > \"/etc/hosts\"'"
    # remove temporary hosts file
    rm "${hosts_file}"
done