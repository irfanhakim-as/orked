#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEP_PATH="${SOURCE_DIR}/../deps"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
LONGHORN_STORAGE_DEVICE="${LONGHORN_STORAGE_DEVICE:-"/dev/sdb"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# dependency check
if [ "$(is_installed "jq")" = "false" ]; then
    echo "ERROR: jq is not installed"
    exit 1
fi

# get all hostnames of worker nodes
worker_hostnames=($(get_values "hostname of worker node"))

# longhorn storage device fstab
longhorn_fstab="${LONGHORN_STORAGE_DEVICE}                /var/lib/longhorn       ext4    defaults        0 0"

# configure longhorn for each worker node
for ((i = 0; i < "${#worker_hostnames[@]}"; i++)); do
    worker_hostname="${worker_hostnames[${i}]}"
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
            mkfs.ext4 ${LONGHORN_STORAGE_DEVICE}

            # mount dedicated data storage
            mount ${LONGHORN_STORAGE_DEVICE} /var/lib/longhorn

            # add to fstab
            if ! grep -Fxq "${longhorn_fstab}" /etc/fstab; then
                echo "${longhorn_fstab}" >> /etc/fstab
            fi
ROOT
EOF
done

# install open-iscsi
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-iscsi-installation.yaml
kubectl apply -f "${DEP_PATH}/longhorn/longhorn-iscsi-installation.yaml"

# wait for longhorn-iscsi-installation to be ready
wait_for_pods default longhorn-iscsi-installation

# install NFSv4 client
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-nfs-installation.yaml
kubectl apply -f "${DEP_PATH}/longhorn/longhorn-nfs-installation.yaml"

# wait for longhorn-nfs-installation to be ready
wait_for_pods default longhorn-nfs-installation

# ensure nodes have all the necessary tools to install longhorn
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/scripts/environment_check.sh
bash "${DEP_PATH}/longhorn/environment_check.sh"

# install longhorn
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/longhorn.yaml
kubectl apply -f "${DEP_PATH}/longhorn/longhorn.yaml"

# wait for longhorn to be ready
wait_for_pods longhorn-system

# check storage class
kubectl get sc