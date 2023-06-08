#!/bin/bash

# configure networking
interface="[keyfile]\nunmanaged-devices=interface-name:cali*;interface-name:flannel*"
echo -e "${interface}" | sudo tee "/etc/NetworkManager/conf.d/rke2-canal.conf" > /dev/null

# disable additional services in rocky linux 8
sudo systemctl disable nm-cloud-setup.service && sudo systemctl disable nm-cloud-setup.timer

# stop and disable firewalld
sudo systemctl disable --now firewalld

# disable swap
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab && sudo swapoff -a

# modify bridge adapter settings
sudo modprobe br_netfilter
bridge="net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1"
echo -e "${bridge}" | sudo tee "/etc/sysctl.d/kubernetes.conf" > /dev/null

# reboot
sudo reboot now