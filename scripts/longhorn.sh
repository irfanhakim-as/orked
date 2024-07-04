#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEP_PATH="${SOURCE_DIR}/../deps"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
SSH_PORT="${SSH_PORT:-"22"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get service user account
service_user=$(get_data "service user account")

# get sudo password
echo "Enter sudo password:"
export sudo_password="$(get_password)"

# get all hostnames of worker nodes
worker_hostnames=($(get_values "hostname of worker node"))

# configure longhorn for each worker node
for ((i = 0; i < "${#worker_hostnames[@]}"; i++)); do
    worker_hostname="${worker_hostnames[${i}]}"
    echo "Configuring longhorn for worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${service_user}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # authenticate as root
        echo "${sudo_password}" | sudo -S su -
        # run as root user
        sudo -i <<- ROOT
            # create longhorn folder
            mkdir -p /var/lib/longhorn

            # format dedicated data storage
            mkfs.ext4 /dev/sdb

            # mount dedicated data storage
            mount /dev/sdb /var/lib/longhorn

            # add to fstab
            echo "/dev/sdb                /var/lib/longhorn       ext4    defaults        0 0" >> /etc/fstab
ROOT
EOF
done

# install open-iscsi
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-iscsi-installation.yaml
kubectl apply -f "${DEP_PATH}/longhorn/longhorn-iscsi-installation.yaml"

# wait for longhorn-iscsi-installation to be ready
wait_for_pods longhorn-system longhorn-iscsi-installation

# install NFSv4 client
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-nfs-installation.yaml
kubectl apply -f "${DEP_PATH}/longhorn/longhorn-nfs-installation.yaml"

# wait for longhorn-nfs-installation to be ready
wait_for_pods longhorn-system longhorn-nfs-installation

# install jq
if [ "$(is_installed "jq")" = "true" ]; then
    echo "jq is already installed"
else
    run_with_sudo yum install -y jq
fi

# ensure nodes have all the necessary tools to install longhorn
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/scripts/environment_check.sh
bash "${DEP_PATH}/longhorn/environment_check.sh"

# install longhorn
# source: https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/longhorn.yaml
kubectl apply -f "${DEP_PATH}/longhorn/longhorn.yaml"

# wait for longhorn to be ready
wait_for_pods longhorn-system

# check storage class
kubectl get sc