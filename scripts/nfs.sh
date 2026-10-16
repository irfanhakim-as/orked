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
print_title "nfs"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
CLEAN_SUDO_PASSWD=$(printf '%q' "${SUDO_PASSWD}")
SSH_PORT="${SSH_PORT:-"22"}"
NFS_SERVER="${NFS_SERVER:-"$(get_data "NFS server address")"}"
NFS_SHARE="${NFS_SHARE:-"$(get_data "NFS share path")"}"
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "NFS_SERVER"
    "NFS_SHARE"
    "WORKER_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# install NFS client and configure SELinux virt_use_nfs for each worker node
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Installing NFS client for worker: ${worker_hostname}"
    # install nfs-utils if not already installed
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" "echo ${CLEAN_SUDO_PASSWD} | sudo -S bash -c 'rpm -q nfs-utils &> /dev/null || dnf install -y nfs-utils'" || { echo "ERROR: Failed to install nfs-utils on ${worker_hostname}"; exit 1; }
    echo "Configuring SELinux virt_use_nfs for worker: ${worker_hostname}"
    # enable SELinux virt_use_nfs
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" "echo ${CLEAN_SUDO_PASSWD} | sudo -S bash -c 'setsebool -P virt_use_nfs 1'"
done

# install csi-driver-nfs
helm upgrade --install csi-driver-nfs csi-driver-nfs \
    --repo https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts \
    --namespace kube-system \
    --create-namespace \
    --version 4.13.5 \
    --wait || { echo "ERROR: Failed to apply csi-driver-nfs installation"; exit 1; }

# wait until no pods are pending
wait_for_pods kube-system csi-nfs

# copy nfs storage class to home directory
cp -f "$(get_dep_path "nfs/storageclass-nfs.yaml")" ~

# set server and share in nfs storage class
sed -i "s#{{ NFS_SERVER }}#${NFS_SERVER}#g" ~/storageclass-nfs.yaml
sed -i "s#{{ NFS_SHARE }}#${NFS_SHARE}#g" ~/storageclass-nfs.yaml

# install nfs storage class
# source: https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/deploy/example/storageclass-nfs.yaml
kubectl apply -f ~/storageclass-nfs.yaml || { echo "ERROR: Failed to apply nfs storageclass"; exit 1; }

# wait for nfs to be ready
# TODO: not sure what to wait for to determine if nfs storageclass is ready
sleep 10

# check storage class
kubectl get sc nfs
