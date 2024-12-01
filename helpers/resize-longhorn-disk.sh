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

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
LONGHORN_STORAGE_DEVICE="${LONGHORN_STORAGE_DEVICE:-"/dev/sdb"}"

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "LONGHORN_STORAGE_DEVICE"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get all hostnames of worker nodes
worker_hostnames=($(get_values "hostname of worker node"))

# get user confirmation
print_title "resize longhorn"
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# resize longhorn disk for each worker node
for ((i = 0; i < "${#worker_hostnames[@]}"; i++)); do
    worker_hostname="${worker_hostnames[${i}]}"
    echo "Resizing Longhorn disk for worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        set -euo pipefail

        # authenticate as root
        echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1

        # run as root user
        sudo -i <<- ROOT
            # validate if device name is a valid device
            if ! lsblk -dpno NAME | grep -q "^${LONGHORN_STORAGE_DEVICE}$"; then
                echo "ERROR: ${LONGHORN_STORAGE_DEVICE} is not a valid device name"; exit 1
            fi

            # ensure longhorn storage is not in use
            if lsof +D /var/lib/longhorn > /dev/null; then
                echo "ERROR: Longhorn storage is currently in use"; exit 1
            fi

            # verify longhorn storage filesystem
            fs_type=\$(lsblk -no FSTYPE "${LONGHORN_STORAGE_DEVICE}")
            if [ "\${fs_type}" != "ext4" ]; then
                echo "ERROR: Unsupported filesystem '\${fs_type}'"; exit 1
            fi

            # unmount longhorn storage
            if ! umount /var/lib/longhorn; then
                echo "ERROR: Failed to unmount /var/lib/longhorn."; exit 1
            fi

            # check storage device for consistency
            e2fsck -f ${LONGHORN_STORAGE_DEVICE}

            # resize longhorn storage partition
            resize2fs ${LONGHORN_STORAGE_DEVICE}

            # remount longhorn storage
            if ! mount "${LONGHORN_STORAGE_DEVICE}"; then
                echo "ERROR: Failed to remount ${LONGHORN_STORAGE_DEVICE} to /var/lib/longhorn."; exit 1
            fi

            # verify new partition size
            df -h /var/lib/longhorn
ROOT
EOF
done