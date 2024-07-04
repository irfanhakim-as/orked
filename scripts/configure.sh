#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SSH_PORT="${SSH_PORT:-"22"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get service user account
service_user=$(get_data "service user account")

# get hostnames of all kubernetes nodes
k8s_hostnames=($(get_values "hostname of kubernetes node"))

# configure each node
for ((i = 0; i < "${#k8s_hostnames[@]}"; i++)); do
    k8s_hostname="${k8s_hostnames[${i}]}"
    echo "Configuring node: ${k8s_hostname}"

    # remote login into kubernetes node
    ssh "${service_user}@${k8s_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # configure networking
        interface="[keyfile]\nunmanaged-devices=interface-name:cali*;interface-name:flannel*"
        command="echo -e \"\${interface}\" | tee '/etc/NetworkManager/conf.d/rke2-canal.conf' > /dev/null"
        echo "${SUDO_PASSWD}" | sudo -S bash -c "\${command}"

        # disable additional services in rocky linux 8
        echo "${SUDO_PASSWD}" | sudo -S bash -c "systemctl disable nm-cloud-setup.service; systemctl disable nm-cloud-setup.timer"

        # stop and disable firewalld
        echo "${SUDO_PASSWD}" | sudo -S bash -c "systemctl disable --now firewalld"

        # disable swap
        echo "${SUDO_PASSWD}" | sudo -S bash -c "sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab && swapoff -a"

        # load br_netfilter kernel module
        echo "${SUDO_PASSWD}" | sudo -S bash -c "modprobe br_netfilter"

        # modify bridge adapter settings
        bridge="net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1"
        command="echo -e \"\${bridge}\" | tee '/etc/sysctl.d/kubernetes.conf' > /dev/null"
        echo "${SUDO_PASSWD}" | sudo -S bash -c "\${command}"

        # reboot
        echo "${SUDO_PASSWD}" | sudo -S bash -c "reboot now"
EOF
done