#!/bin/bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# script path
SCRIPT_PATH="${SOURCE_DIR}/../scripts"

# get service user account
service_user=$(bash "${SCRIPT_PATH}/utils.sh" --get-data "service user account")

# get sudo password
echo "Enter sudo password:"
sudo_password=$(bash "${SCRIPT_PATH}/utils.sh" --get-password)

# get all hostnames of worker nodes
worker_hostnames=($(bash "${SCRIPT_PATH}/utils.sh" --get-values "hostname of worker node"))

# toggle SELinux for each worker node
for ((i = 0; i < ${#worker_hostnames[@]}; i++)); do
  worker_hostname="${worker_hostnames[${i}]}"
  echo "Toggling SELinux for worker: ${worker_hostname}"

  # remote login into worker node
  ssh "${service_user}@${worker_hostname}" 'bash -s' << EOF
    # check current status of SELinux
    status=\$(sestatus | grep "Current mode" | awk '{print \$3}')
    # toggle SELinux
    if [ "\${status}" == "enforcing" ]; then
      echo ${sudo_password} | sudo -S bash -c "setenforce 0"
    else
      echo ${sudo_password} | sudo -S bash -c "setenforce 1"
    fi
    # echo latest status of SELinux
    echo "SELinux has been toggled to: \$(sestatus | grep "Current mode" | awk '{print \$3}')"
EOF
done