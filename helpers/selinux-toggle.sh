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
print_title "selinux"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "WORKER_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# toggle SELinux for each worker node
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Toggling SELinux for worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # check current status of SELinux
        status=\$(sestatus | grep "Current mode" | awk '{print \$3}')
        # toggle SELinux
        if [ "\${status}" == "enforcing" ]; then
            echo "${SUDO_PASSWD}" | sudo -S bash -c "setenforce 0"
        else
            echo "${SUDO_PASSWD}" | sudo -S bash -c "setenforce 1"
        fi
        # echo latest status of SELinux
        echo "SELinux has been toggled to: \$(sestatus | grep "Current mode" | awk '{print \$3}')"
EOF
done