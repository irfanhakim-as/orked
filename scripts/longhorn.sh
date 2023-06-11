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

    # start and enable RKE2 agent service
    systemctl enable --now rke2-agent.service
EOF
done

# install jq
sudo yum install -y jq