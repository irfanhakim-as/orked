#!/bin/bash

# get all hostnames of master nodes
master_hostnames=$(bash ./utils.sh --get-values "hostname of master node")

# get all hostnames of worker nodes
worker_hostnames=$(bash ./utils.sh --get-values "hostname of worker node")

# configure master node 1
configure_master=$(ssh "root@${master_hostnames[0]}" '
  # download the RKE installer
  curl -sfL https://get.rke2.io -o install.sh
  chmod +x install.sh

  # run the RKE installer
  INSTALL_RKE2_CHANNEL=stable;INSTALL_RKE2_TYPE="server" ./install.sh

  # create RKE config
  config_content=$(cat << EOF
tls-san:
  - \${master_hostnames[0]}
  - \${master_hostnames[1]}
  - \${master_hostnames[2]}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
disable: rke2-ingress-nginx
write-kubeconfig-mode: 644
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
EOF
)
  echo "\${config_content}" > /etc/rancher/rke2/config.yaml

  # restart RKE2 server service
  systemctl restart rke2-server.service

  # Retrieve the token value
  token=$(cat /var/lib/rancher/rke2/server/node-token)
  echo "${token}"
')

# extract master node 1 token
token=$(echo "${configure_master}" | tail -n 1)

# configure the rest of the master nodes
for ((i = 1; i < ${#master_hostnames[@]}; i++)); do
  master_hostname="${master_hostnames[$i]}"
  echo "Configuring master: ${master_hostname}"

  # remote login into master node
  ssh "root@${master_hostname}" '
    # download the RKE installer
    curl -sfL https://get.rke2.io -o install.sh
    chmod +x install.sh

    # run the RKE installer
    INSTALL_RKE2_CHANNEL=stable;INSTALL_RKE2_TYPE="server" ./install.sh

    # create RKE config
    config_content=$(cat << EOF
server: https://\${master_hostnames[0]}:9345
token: \${token}
write-kubeconfig-mode: "0644"
tls-san:
  - \${master_hostnames[0]}
  - \${master_hostnames[1]}
  - \${master_hostnames[2]}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
disable: rke2-ingress-nginx
EOF
)
    echo "\${config_content}" > /etc/rancher/rke2/config.yaml

    # start and enable RKE2 server service
    systemctl enable --now rke2-server.service
'
done

# configure the worker nodes
for ((i = 0; i < ${#worker_hostnames[@]}; i++)); do
  worker_hostname="${worker_hostnames[$i]}"
  echo "Configuring worker: ${worker_hostname}"

  # remote login into worker node
  ssh "root@${worker_hostname}" '
    # download the RKE installer
    curl -sfL https://get.rke2.io -o install.sh
    chmod +x install.sh

    # run the RKE installer
    INSTALL_RKE2_CHANNEL=stable;INSTALL_RKE2_TYPE="agent" ./install.sh

    # create RKE config
    config_content=$(cat << EOF
server: https://\${worker_hostnames[0]}:9345
token: \${token}
EOF
)
    echo "\${config_content}" > /etc/rancher/rke2/config.yaml

    # start and enable RKE2 agent service
    systemctl enable --now rke2-agent.service
'
done

# create kubeconfig folder
mkdir -p ~/.kube

# copy kubeconfig file from master node 1
scp "root@${master_hostnames[0]}:/etc/rancher/rke2/rke2.yaml" ~/.kube/config

# replace localhost with master node 1 hostname
sed -i "s/127\.0\.0\.1/${master_hostnames[0]}/g" ~/.kube/config

# label worker nodes as worker
for ((i = 0; i < ${#worker_hostnames[@]}; i++)); do
  kubectl label node ${worker_hostnames[$i]} node-role.kubernetes.io/worker=worker
done

# check cluster status
kubectl get nodes -o wide