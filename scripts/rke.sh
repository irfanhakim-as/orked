#!/bin/bash

# loop get all master_hostnames of master nodes
master_hostnames=()
index=0
while true; do
    index=$((index+1))
    read -p "Enter master node ${index} [Enter to quit]: " master_hostname
    if [ -z "${master_hostname}" ]; then
        break
    fi
    master_hostnames+=("${master_hostname}")
done

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
    echo "Processing hostname: $master_hostname"
    
    # remote login into master node
    ssh "root@${master_hostname}" << EOF
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
EOF
done