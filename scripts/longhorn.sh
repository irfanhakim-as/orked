#!/bin/bash

# loop get all hostnames of worker nodes
worker_hostnames=()
index=0
while true; do
  index=$((index+1))
  read -p "Enter worker node ${index} [Enter to quit]: " worker_hostname
  if [ -z "${worker_hostname}" ]; then
      break
  fi
  worker_hostnames+=("${worker_hostname}")
done

# configure longhorn for each worker node
for ((i = 0; i < ${#worker_hostnames[@]}; i++)); do
  worker_hostname="${worker_hostnames[$i]}"
  echo "Configuring longhorn for worker: $worker_hostname"

  # remote login into worker node
  ssh "root@${worker_hostname}" << EOF
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
while true; do
  longhorn_iscsi_pod=$(kubectl get pods -n longhorn-system | grep 'Running' | grep 'longhorn-iscsi-installation' | awk '{print $1}')
  if [ -z "${longhorn_iscsi_pod}" ]; then
    echo "Waiting for longhorn-iscsi-installation to be ready..."
    sleep 5
  else
    break
  fi
done

# install NFSv4 client
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/prerequisite/longhorn-nfs-installation.yaml

# wait for longhorn-nfs-installation to be ready
while true; do
  longhorn_nfs_pod=$(kubectl get pods -n longhorn-system | grep 'Running' | grep 'longhorn-nfs-installation' | awk '{print $1}')
  if [ -z "${longhorn_nfs_pod}" ]; then
    echo "Waiting for longhorn-nfs-installation to be ready..."
    sleep 5
  else
    break
  fi
done

# install jq
sudo yum install -y jq

# ensure nodes have all the necessary tools to install longhorn
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/scripts/environment_check.sh | bash

# install longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/longhorn.yaml

# wait for longhorn to be ready
while true; do
  longhorn_pod=$(kubectl get pods -n longhorn-system | grep 'Running' | grep 'longhorn-manager' | awk '{print $1}')
  if [ -z "${longhorn_pod}" ]; then
    echo "Waiting for longhorn to be ready..."
    sleep 5
  else
    break
  fi
done

# check storage class
kubectl get sc