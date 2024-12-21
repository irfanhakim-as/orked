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
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "LONGHORN_STORAGE_DEVICE"
    "WORKER_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
print_title "resize longhorn"
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# resize longhorn disk for each worker node
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Resizing Longhorn disk for worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        set -euo pipefail

        # authenticate as root
        echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1

        # validate if device name is a valid device
        if ! lsblk -dpno NAME | grep -q "^${LONGHORN_STORAGE_DEVICE}$"; then
            echo "ERROR: ${LONGHORN_STORAGE_DEVICE} is not a valid device name"; exit 1
        fi

        # verify longhorn storage filesystem
        fs_type=\$(lsblk -no FSTYPE "${LONGHORN_STORAGE_DEVICE}")
        if [ "\${fs_type}" != "ext4" ]; then
            echo "ERROR: Unsupported filesystem (\${fs_type})"; exit 1
        fi

        # run as root user
        sudo -i <<- ROOT
            # unmount longhorn storage if mounted
            if findmnt "/var/lib/longhorn"; then
                if ! umount "/var/lib/longhorn"; then
                    echo "ERROR: Failed to unmount /var/lib/longhorn"; exit 1
                fi
                echo "Unmounted /var/lib/longhorn successfully"
            fi

            # check storage device for consistency
            if e2fsck -f -y "${LONGHORN_STORAGE_DEVICE}"; then
                # resize longhorn storage partition
                resize2fs "${LONGHORN_STORAGE_DEVICE}" && echo "Resized ${LONGHORN_STORAGE_DEVICE} successfully" || { echo "ERROR: Failed to resize ${LONGHORN_STORAGE_DEVICE}"; exit 1; }
            else
                echo "ERROR: Failed to check ${LONGHORN_STORAGE_DEVICE} for consistency"; exit 1
            fi

            # remount longhorn storage if not mounted
            if ! findmnt "/var/lib/longhorn"; then
                if ! mount "${LONGHORN_STORAGE_DEVICE}"; then
                    echo "ERROR: Failed to remount ${LONGHORN_STORAGE_DEVICE} to /var/lib/longhorn"; exit 1
                fi
                echo "Mounted /var/lib/longhorn successfully"
            fi

            # verify new partition size
            df -h "/var/lib/longhorn"
ROOT
EOF
done