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
print_title "node configuration"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"
KUBERNETES_NODES=(${KUBERNETES_NODES})
if [ "${#KUBERNETES_NODES[@]}" -lt 1 ]; then
    MASTER_NODES=(${MASTER_NODES:-$(get_values "hostname of master node")})
    WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})
    # get hostnames of all kubernetes nodes
    KUBERNETES_NODES=("${MASTER_NODES[@]}" "${WORKER_NODES[@]}")
fi

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "KUBERNETES_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# configure each node
for ((i = 0; i < "${#KUBERNETES_NODES[@]}"; i++)); do
    k8s_hostname="${KUBERNETES_NODES[${i}]}"
    echo "Configuring node: ${k8s_hostname}"

    # remote login into kubernetes node
    ssh "${SERVICE_USER}@${k8s_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # authenticate as root
        echo "${SUDO_PASSWD}" | sudo -S su - > /dev/null 2>&1
        # run as root user
        sudo -i <<- 'ROOT'
            # configure networking
            interface="[keyfile]\nunmanaged-devices=interface-name:cali*;interface-name:flannel*"
            echo -e "\${interface}" | tee "/etc/NetworkManager/conf.d/rke2-canal.conf" > /dev/null

            # disable additional services in rocky linux 8
            systemctl disable nm-cloud-setup.service; systemctl disable nm-cloud-setup.timer

            # stop and disable firewalld
            systemctl disable --now firewalld

            # disable swap
            sed -i "/ swap / s/^\(.*\)$/#\1/g" /etc/fstab && swapoff -a

            # load br_netfilter kernel module
            modprobe br_netfilter && ls -la /sys/module/ | grep br_netfilter

            # modify bridge adapter settings
            bridge="net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1"
            echo -e "\${bridge}" | tee "/etc/sysctl.d/kubernetes.conf" > /dev/null

            # reboot
            reboot now
ROOT
EOF
done