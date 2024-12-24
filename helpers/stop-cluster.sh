#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
SCRIPT_DIR="${ROOT_DIR}/scripts"
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SCRIPT_DIR}/utils.sh"

# print title
print_title "stop cluster"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
MASTER_NODES=(${MASTER_NODES:-$(get_values "hostname of master node")})
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})
SHUTDOWN_NODES="$(get_bool "shutdown all nodes")"; echo
DRAIN_OPTS="${DRAIN_OPTS:+ ${DRAIN_OPTS}}"

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "MASTER_NODES"
    "WORKER_NODES"
    "SHUTDOWN_NODES"
    "DRAIN_OPTS"
)

# optional variables
opt_variables=(
    "MASTER_NODES"
    "WORKER_NODES"
    "DRAIN_OPTS"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}" "${opt_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# flag all worker nodes as unschedulable
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Cordoning worker: ${worker_hostname}"
    kubectl cordon "${worker_hostname}"
done

# drain all worker nodes
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Draining worker: ${worker_hostname}"
    kubectl drain "${worker_hostname}" --force --delete-emptydir-data --ignore-daemonsets --timeout 0"${DRAIN_OPTS}"
    # kill worker node
    echo "Killing worker: ${worker_hostname}"
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # kill all kubernetes processes
        echo "${SUDO_PASSWD}" | sudo -S rke2-killall.sh
EOF
    # wait for worker nodes to drain completely
    wait_for_node_readiness "${worker_hostname}" "false"
    # shut down worker nodes if specified
    if [ "${SHUTDOWN_NODES}" == "true" ]; then
        echo "Shutting down worker: ${worker_hostname} in 5s..."
        sleep 5
        # shut down worker node
        ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
            # shutdown the node
            echo "${SUDO_PASSWD}" | sudo -S shutdown now
EOF
    fi
done

# flag all worker nodes as schedulable
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Uncordoning worker: ${worker_hostname}"
    kubectl uncordon "${worker_hostname}"
done

# stop master nodes in reverse order
for ((i = "${#MASTER_NODES[@]}" - 1; i >= 0; i--)); do
    master_hostname="${MASTER_NODES[${i}]}"
    # kill master node
    echo "Killing master: ${worker_hostname}"
    # remote login into master node
    ssh "${SERVICE_USER}@${master_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # kill all kubernetes processes
        echo "${SUDO_PASSWD}" | sudo -S rke2-killall.sh
        # shut down master nodes if specified
        if [ "${SHUTDOWN_NODES}" == "true" ]; then
            echo "Shutting down master: ${master_hostname} in 5s..."
            sleep 5
            echo "${SUDO_PASSWD}" | sudo -S shutdown now
        fi
EOF
done