#!/bin/bash

# generate ecdsa ssh key
if ! [ -f "~/.ssh/id_ecdsa.pub" ]; then
    echo "Generating SSH key (ecdsa)"
    # ssh-keygen -t ecdsa -f ~/.ssh/id_ecdsa -N ''
else
    echo "SSH key already exists (ecdsa)"
fi

# get service user account
read -p "Enter service user account for all nodes: " service_user

# loop get all hostnames from user as user input, stop when user input is empty
hostnames=()
index=0
while true; do
    index=$((index+1))
    read -p "Enter node ${index} [Enter to quit]: " hostname
    if [ -z "${hostname}" ]; then
        break
    fi
    hostnames+=("${hostname}")
done

# print the given hostnames
echo "Nodes:"
for hostname in "${hostnames[@]}"; do
    echo "Copying public SSH key to ${service_user}@${hostname}"
    ssh-copy-id -i ~/.ssh/id_ecdsa.pub ${service_user}@${hostname}
done