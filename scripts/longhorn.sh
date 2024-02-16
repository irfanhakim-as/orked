#!/bin/bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# get sudo password
echo "Enter sudo password:"
sudo_password=$(bash "${SOURCE_DIR}/utils.sh" --get-password)

# get all hostnames of worker nodes
worker_hostnames=($(bash "${SOURCE_DIR}/utils.sh" --get-values "hostname of worker node"))

# configure longhorn for each worker node
for ((i = 0; i < ${#worker_hostnames[@]}; i++)); do
  worker_hostname="${worker_hostnames[${i}]}"
  echo "Configuring longhorn for worker: ${worker_hostname}"

  # remote login into worker node
  ssh "root@${worker_hostname}" 'bash -s' << EOF
    # create longhorn folder
    mkdir -p /var/lib/longhorn

    # format dedicated data storage
    mkfs.ext4 /dev/sdb

    # mount dedicated data storage
    mount /dev/sdb /var/lib/longhorn

    # add to fstab
    echo "/dev/sdb                /var/lib/longhorn       ext4    defaults        0 0" >> /etc/fstab
EOF
done

# install open-iscsi
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-iscsi-installation.yaml

# wait for longhorn-iscsi-installation to be ready
bash "${SOURCE_DIR}/utils.sh" --wait-for-pods longhorn-system longhorn-iscsi-installation

# install NFSv4 client
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-nfs-installation.yaml

# wait for longhorn-nfs-installation to be ready
bash "${SOURCE_DIR}/utils.sh" --wait-for-pods longhorn-system longhorn-nfs-installation

# install jq
if [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed jq)" = "true" ]; then
  echo "jq is already installed"
else
  echo ${sudo_password} | sudo -S bash -c "yum install -y jq"
fi

# ensure nodes have all the necessary tools to install longhorn
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/scripts/environment_check.sh | bash

# install longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/longhorn.yaml

# wait for longhorn to be ready
bash "${SOURCE_DIR}/utils.sh" --wait-for-pods longhorn-system

# check storage class
kubectl get sc