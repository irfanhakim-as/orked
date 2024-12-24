#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
DEP_DIR="${ROOT_DIR}/deps"
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SOURCE_DIR}/utils.sh"

# print title
print_title "longhorn"

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
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# longhorn storage device fstab
longhorn_fstab="${LONGHORN_STORAGE_DEVICE}                /var/lib/longhorn       ext4    defaults        0 0"

# configure longhorn for each worker node
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Configuring longhorn for worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # authenticate as root
        echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1
        # run as root user
        sudo -i <<- ROOT
            # validate if device name is a valid device
            if ! lsblk -dpno NAME | grep -q "^${LONGHORN_STORAGE_DEVICE}$"; then
                echo "ERROR: ${LONGHORN_STORAGE_DEVICE} is not a valid device name"
                exit 1
            fi

            # create longhorn folder
            mkdir -p /var/lib/longhorn

            # format dedicated data storage
            if ! lsblk -no FSTYPE "${LONGHORN_STORAGE_DEVICE}" | grep -q .; then
                mkfs.ext4 ${LONGHORN_STORAGE_DEVICE} && echo "Formatted ${LONGHORN_STORAGE_DEVICE} to ext4 successfully" || { echo "ERROR: Failed to format ${LONGHORN_STORAGE_DEVICE}"; exit 1; }
            else
                echo "WARNING: ${LONGHORN_STORAGE_DEVICE} has already been formatted"
            fi

            # mount dedicated data storage
            if ! findmnt --target "/var/lib/longhorn" --source "${LONGHORN_STORAGE_DEVICE}" > /dev/null 2>&1; then
                mount "${LONGHORN_STORAGE_DEVICE}" /var/lib/longhorn && echo "Mounted ${LONGHORN_STORAGE_DEVICE} to /var/lib/longhorn successfully" || { echo "ERROR: Failed to mount ${LONGHORN_STORAGE_DEVICE} to /var/lib/longhorn"; exit 1; }
            else
                echo "WARNING: ${LONGHORN_STORAGE_DEVICE} has already been mounted to /var/lib/longhorn"
            fi

            # add to fstab
            if ! grep -Fxq "${longhorn_fstab}" /etc/fstab; then
                echo "${longhorn_fstab}" >> /etc/fstab
            else
                echo "WARNING: ${LONGHORN_STORAGE_DEVICE} has already been set to automount"
            fi
ROOT
EOF
done

# install open-iscsi
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-iscsi-installation.yaml
kubectl apply -f "${DEP_DIR}/longhorn/longhorn-iscsi-installation.yaml"

# wait for longhorn-iscsi-installation to be ready
wait_for_pods default longhorn-iscsi-installation

# install NFSv4 client
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-nfs-installation.yaml
kubectl apply -f "${DEP_DIR}/longhorn/longhorn-nfs-installation.yaml"

# wait for longhorn-nfs-installation to be ready
wait_for_pods default longhorn-nfs-installation

# ensure nodes have all the necessary tools to install longhorn
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/scripts/environment_check.sh
bash "${DEP_DIR}/longhorn/environment_check.sh"

# install longhorn
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/longhorn.yaml
kubectl apply -f "${DEP_DIR}/longhorn/longhorn.yaml"

# wait for longhorn to be ready
wait_for_pods longhorn-system

# check storage class
kubectl get sc longhorn