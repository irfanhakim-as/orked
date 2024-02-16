#!/bin/bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# get service user account
service_user=$(bash "${SOURCE_DIR}/utils.sh" --get-data "service user account")

# get sudo password
echo "Enter sudo password:"
sudo_password=$(bash "${SOURCE_DIR}/utils.sh" --get-password)

# get hostnames of all kubernetes nodes
kubernetes_hostnames=($(bash "${SOURCE_DIR}/utils.sh" --get-values "hostname of kubernetes node"))

# configure each node
for ((i = 0; i < ${#kubernetes_hostnames[@]}; i++)); do
    kubernetes_hostname="${kubernetes_hostnames[${i}]}"
    echo "Configuring node: ${kubernetes_hostname}"

    # remote login into kubernetes node
    ssh "${service_user}@${kubernetes_hostname}" 'bash -s' << EOF
        # configure networking
        interface="[keyfile]\nunmanaged-devices=interface-name:cali*;interface-name:flannel*"
        command="echo -e \"\${interface}\" | tee '/etc/NetworkManager/conf.d/rke2-canal.conf' > /dev/null"
        echo ${sudo_password} | sudo -S bash -c "\${command}"

        # disable additional services in rocky linux 8
        echo ${sudo_password} | sudo -S bash -c "systemctl disable nm-cloud-setup.service; systemctl disable nm-cloud-setup.timer"

        # stop and disable firewalld
        echo ${sudo_password} | sudo -S bash -c "systemctl disable --now firewalld"

        # disable swap
        echo ${sudo_password} | sudo -S bash -c "sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab && swapoff -a"

        # load br_netfilter kernel module
        echo ${sudo_password} | sudo -S bash -c "modprobe br_netfilter"

        # modify bridge adapter settings
        bridge="net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1"
        command="echo -e \"\${bridge}\" | tee '/etc/sysctl.d/kubernetes.conf' > /dev/null"
        echo ${sudo_password} | sudo -S bash -c "\${command}"

        # reboot
        echo ${sudo_password} | sudo -S bash -c "reboot now"
EOF
done