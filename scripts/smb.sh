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
print_title "SMB"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
SMB_USER="${SMB_USER:-"$(get_data "SMB username")"}"
SMB_PASSWD="${SMB_PASSWD:-"$(get_password "SMB password")"}"
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "SMB_USER"
    "SMB_PASSWD"
    "WORKER_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# configure SELinux virt_use_samba for each worker node
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Configuring SELinux virt_use_samba for worker: ${worker_hostname}"
    # enable SELinux virt_use_samba
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'setsebool -P virt_use_samba 1'"
done

# add helm repo
if ! helm repo list 2>&1 | grep -q "csi-driver-smb"; then
    helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
fi

# update helm repo
helm repo update csi-driver-smb

# install csi-driver-smb
helm upgrade --install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace kube-system --create-namespace --version v1.14.0 --wait

# wait until no pods are pending
wait_for_pods kube-system csi-smb

# create a secret for the SMB share if not already created
if ! kubectl get secret smbcreds --namespace default &> /dev/null; then
    kubectl create secret generic smbcreds --from-literal username="${SMB_USER}" --from-literal password="${SMB_PASSWD}" --namespace default
fi

# install smb storage class
# source: https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/deploy/example/storageclass-smb.yaml
kubectl apply -f "${DEP_DIR}/smb/storageclass-smb.yaml"

# wait for smb to be ready
# TODO: not sure what to wait for to determine if smb storageclass is ready
sleep 10

# check storage class
kubectl get sc smb