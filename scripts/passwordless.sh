#!/bin/bash

# get service user account
service_user=$(bash ./utils.sh --get-data "service user account")

# get hostnames of all kubernetes nodes
kubernetes_hostnames=($(bash ./utils.sh --get-values "hostname of kubernetes node"))

# generate ecdsa ssh key
if ! [ -f "${HOME}/.ssh/id_ecdsa.pub" ]; then
    echo "Generating SSH key (ecdsa)"
    ssh-keygen -t ecdsa -f ~/.ssh/id_ecdsa -N ''
else
    echo "SSH key already exists (ecdsa)"
fi

# copy SSH key to each node
echo "Nodes:"
for kubernetes_hostname in "${kubernetes_hostnames[@]}"; do
    echo "Copying public SSH key to ${service_user}@${kubernetes_hostname}"
    ssh-copy-id -i ~/.ssh/id_ecdsa.pub "${service_user}@${kubernetes_hostname}"
done