#!/bin/bash

# get service user account
service_user=$(bash ./utils.sh --get-data "service user account")

# generate ecdsa ssh key
if ! [ -f "~/.ssh/id_ecdsa.pub" ]; then
    echo "Generating SSH key (ecdsa)"
    ssh-keygen -t ecdsa -f ~/.ssh/id_ecdsa -N ''
else
    echo "SSH key already exists (ecdsa)"
fi

# loop get all hostnames from user as user input, stop when user input is empty
hostnames=($(bash ./utils.sh --get-values "hostname of node"))

# print the given hostnames
echo "Nodes:"
for hostname in "${hostnames[@]}"; do
    echo "Copying public SSH key to ${service_user}@${hostname}"
    ssh-copy-id -i ~/.ssh/id_ecdsa.pub ${service_user}@${hostname}
done