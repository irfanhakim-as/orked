#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SOURCE_DIR}/utils.sh"

# print title
print_title "rke2"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
RKE2_CHANNEL="${RKE2_CHANNEL:-"stable"}"
RKE2_VERSION="${RKE2_VERSION:-"v1.25.15+rke2r2"}"
RKE2_SCRIPT_URL="${RKE2_SCRIPT_URL:-"https://get.rke2.io"}"
RKE2_CLUSTER_CIDR="${RKE2_CLUSTER_CIDR:-"10.42.0.0/16"}"
RKE2_SERVICE_CIDR="${RKE2_SERVICE_CIDR:-"10.43.0.0/16"}"
MASTER_NODES=(${MASTER_NODES:-$(get_values "hostname of master node")})
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "RKE2_CHANNEL"
    "RKE2_VERSION"
    "RKE2_SCRIPT_URL"
    "RKE2_CLUSTER_CIDR"
    "RKE2_SERVICE_CIDR"
    "MASTER_NODES"
    "WORKER_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# validate number of master and worker nodes
if [ "${#MASTER_NODES[@]}" -lt 1 ] || [ "${#WORKER_NODES[@]}" -lt 1 ]; then
    echo "ERROR: There must be at least 1 master and 1 worker node"
    exit 1
fi

# download rke2 install script
rke2_installer="$(curl -sfL ${RKE2_SCRIPT_URL})"
# ensure script was downloaded
if [ -z "${rke2_installer}" ]; then
    echo "ERROR: Failed to download RKE2 install script (${RKE2_SCRIPT_URL})"
    exit 1
fi
# encode the script for secure transfer
rke2_installer_secret="$(echo "${rke2_installer}" | base64)"

# construct the tls-san section dynamically
tls_san_section=""
for hostname in "${MASTER_NODES[@]}"; do
    tls_san_section+="  - ${hostname}"$'\n'
done
# remove last newline
tls_san_section="$(echo "${tls_san_section}" | sed '$ s/.$//')"

# configure master node 1
echo "Configuring primary master: ${MASTER_NODES[0]}"
configure_master=$(ssh "${SERVICE_USER}@${MASTER_NODES[0]}" -p "${SSH_PORT}" 'bash -s' <<- EOF
    # authenticate as root
    echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1
    # run as root user
    sudo -i <<- 'ROOT'
        # download the RKE installer
        echo "${rke2_installer_secret}" | base64 --decode > ./rke2.sh
        chmod +x ./rke2.sh

        # run the RKE installer
        INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL}" INSTALL_RKE2_VERSION="${RKE2_VERSION}" INSTALL_RKE2_TYPE="server" ./rke2.sh

        # create RKE config
        cat <<- FOE > /etc/rancher/rke2/config.yaml
tls-san:
${tls_san_section}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
disable: rke2-ingress-nginx
write-kubeconfig-mode: 644
cluster-cidr: ${RKE2_CLUSTER_CIDR}
service-cidr: ${RKE2_SERVICE_CIDR}
FOE

        # enable RKE2 server service
        systemctl enable rke2-server.service

        # restart RKE2 server service
        systemctl restart rke2-server.service

        # return the token value
        token="\$(cat /var/lib/rancher/rke2/server/node-token)"
        echo "\${token}"
ROOT
EOF
)

# extract master node 1 token
# WARN: current implementation is insufficient in case of errors as the returned output may not actually contain the token
token="$(echo "${configure_master}" | tail -n 1)"

# validate token is not empty
if [ -z "${token}" ]; then
    echo "ERROR: primary master node token was not extracted successfully"
    exit 1
else
    echo "Primary master node token: \"${token}\""
fi

# configure the rest of the master nodes
for ((i = 1; i < "${#MASTER_NODES[@]}"; i++)); do
    master_hostname="${MASTER_NODES[${i}]}"
    echo "Configuring master: ${master_hostname}"

    # remote login into master node
    ssh "${SERVICE_USER}@${master_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # authenticate as root
        echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1
        # run as root user
        sudo -i <<- ROOT
            # download the RKE installer
            echo "${rke2_installer_secret}" | base64 --decode > ./rke2.sh
            chmod +x ./rke2.sh

            # run the RKE installer
            INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL}" INSTALL_RKE2_VERSION="${RKE2_VERSION}" INSTALL_RKE2_TYPE="server" ./rke2.sh

            # create RKE config
            cat <<- FOE > /etc/rancher/rke2/config.yaml
server: https://${MASTER_NODES[0]}:9345
token: ${token}
tls-san:
${tls_san_section}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
disable: rke2-ingress-nginx
write-kubeconfig-mode: 644
cluster-cidr: ${RKE2_CLUSTER_CIDR}
service-cidr: ${RKE2_SERVICE_CIDR}
FOE

            # start and enable RKE2 server service
            systemctl enable --now rke2-server.service
ROOT
EOF
done

# configure the worker nodes
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    echo "Configuring worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # authenticate as root
        echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1
        # run as root user
        sudo -i <<- ROOT
            # download the RKE installer
            echo "${rke2_installer_secret}" | base64 --decode > ./rke2.sh
            chmod +x ./rke2.sh

            # run the RKE installer
            INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL}" INSTALL_RKE2_VERSION="${RKE2_VERSION}" INSTALL_RKE2_TYPE="agent" ./rke2.sh

            # create RKE config
            cat <<- FOE > /etc/rancher/rke2/config.yaml
server: https://${MASTER_NODES[0]}:9345
token: ${token}
FOE

            # start and enable RKE2 agent service
            systemctl enable --now rke2-agent.service
ROOT
EOF
done

# create kubeconfig folder
mkdir -p ~/.kube

# copy kubeconfig file from master node 1
ssh "${SERVICE_USER}@${MASTER_NODES[0]}" -p "${SSH_PORT}" "echo \"${SUDO_PASSWD}\" | sudo -S bash -c 'cat \"/etc/rancher/rke2/rke2.yaml\"'" > ~/.kube/config

# validate if kubeconfig has been downloaded
if [ ! -f ~/.kube/config ]; then
    echo "ERROR: kubeconfig file was not extracted successfully"
    exit 1
fi

# replace localhost with master node 1 hostname
sed -i "s/127\.0\.0\.1/${MASTER_NODES[0]}/g" ~/.kube/config

# update kubeconfig permissions
chmod 600 ~/.kube/config

# label worker nodes as worker
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    kubectl label node "${WORKER_NODES[${i}]}" node-role.kubernetes.io/worker=worker
done

# wait for cluster nodes to be ready
# TODO: not sure what to wait for to determine if all nodes are ready
sleep 10

# check cluster status
kubectl get nodes -o wide