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
print_title "kubeconfig"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
CLEAN_SUDO_PASSWD=$(printf '%q' "${SUDO_PASSWD}")
SSH_PORT="${SSH_PORT:-"22"}"
RKE2_CERT_RENEWAL_DAYS="${RKE2_CERT_RENEWAL_DAYS:-"120"}"
MASTER_NODES=(${MASTER_NODES:-$(get_values "hostname of master node")})
LB_NODE="${LB_NODE}"
LB_NODE_IP="${LB_NODE_IP}"

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "RKE2_CERT_RENEWAL_DAYS"
    "MASTER_NODES"
    "LB_NODE"
    "LB_NODE_IP"
)

# optional variables
opt_variables=(
    "LB_NODE"
    "LB_NODE_IP"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}" "${opt_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# validate number of master nodes
if [ "${#MASTER_NODES[@]}" -lt 1 ]; then
    echo "ERROR: There must be at least 1 master node"
    exit 1
fi

# determine cluster server endpoint
if [ -n "${LB_NODE}" ] && [ -n "${LB_NODE_IP}" ]; then
    SERVER_ENDPOINT="${LB_NODE}"
else
    SERVER_ENDPOINT="${MASTER_NODES[0]}"
fi

# rke2 paths on the master nodes
RKE2_ADMIN_CERT="/var/lib/rancher/rke2/server/tls/client-admin.crt"
RKE2_KUBECTL="/var/lib/rancher/rke2/bin/kubectl"
RKE2_KUBECONFIG="/etc/rancher/rke2/rke2.yaml"

# renew the certificates of each master node one at a time
for hostname in "${MASTER_NODES[@]}"; do
    # skip the master node if its certificates are not due for renewal
    if ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo ${CLEAN_SUDO_PASSWD} | sudo -S openssl x509 -noout -checkend $((RKE2_CERT_RENEWAL_DAYS * 86400)) -in ${RKE2_ADMIN_CERT}" &> /dev/null; then
        echo "Certificates of ${hostname} are not due for renewal"
        continue
    fi

    # restart rke2 to renew the certificates
    echo "Renewing certificates of ${hostname}"
    ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo ${CLEAN_SUDO_PASSWD} | sudo -S systemctl restart rke2-server" || { echo "ERROR: Failed to restart rke2-server on ${hostname}"; exit 1; }

    # wait until the api server of the master node is ready
    attempts=0
    until ssh "${SERVICE_USER}@${hostname}" -p "${SSH_PORT}" "echo ${CLEAN_SUDO_PASSWD} | sudo -S ${RKE2_KUBECTL} --kubeconfig ${RKE2_KUBECONFIG} get --raw /readyz" &> /dev/null; do
        attempts=$((attempts + 1))
        if [ "${attempts}" -ge 60 ]; then
            echo "ERROR: The API server of ${hostname} did not become ready"
            exit 1
        fi
        echo "Waiting for the API server of ${hostname} to become ready..."
        sleep 5
    done
done

# create kubeconfig folder
mkdir -p ~/.kube

# copy kubeconfig file from master node 1
kubeconfig_file="$(mktemp)"
ssh "${SERVICE_USER}@${MASTER_NODES[0]}" -p "${SSH_PORT}" "echo ${CLEAN_SUDO_PASSWD} | sudo -S bash -c 'cat \"${RKE2_KUBECONFIG}\"'" > "${kubeconfig_file}"

# validate if kubeconfig has been downloaded
if [ ! -s "${kubeconfig_file}" ]; then
    rm -f "${kubeconfig_file}"
    echo "ERROR: kubeconfig file was not extracted successfully"
    exit 1
fi

# replace localhost with the cluster server endpoint
sed -i "s/127\.0\.0\.1/${SERVER_ENDPOINT}/g" "${kubeconfig_file}"

# back up the existing kubeconfig
if [ -f ~/.kube/config ]; then
    cp -f ~/.kube/config ~/.kube/config.bak
fi

# replace the existing kubeconfig
mv -f "${kubeconfig_file}" ~/.kube/config

# update kubeconfig permissions
chmod 600 ~/.kube/config

# check cluster status
kubectl get nodes -o wide
