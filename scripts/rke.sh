#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
SSH_PORT="${SSH_PORT:-"22"}"
RKE2_CHANNEL="${RKE2_CHANNEL:-"stable"}"
RKE2_VERSION="${RKE2_VERSION:-"v1.25.15+rke2r2"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get service user account
service_user=$(get_data "service user account")

# get sudo password
echo "Enter sudo password:"
export sudo_password="$(get_password)"

# get all hostnames of master nodes
master_hostnames=($(get_values "hostname of master node"))

# get all hostnames of worker nodes
worker_hostnames=($(get_values "hostname of worker node"))

# configure master node 1
configure_master=$(ssh "${service_user}@${master_hostnames[0]}" -p "${SSH_PORT}" 'bash -s' <<- EOF
    # variables
    master_hostnames=(${master_hostnames[@]})

    # construct the tls-san section dynamically
    tls_san_section=""
    for hostname in "\${master_hostnames[@]}"; do
        tls_san_section+="  - \${hostname}"\$'\n'
    done
    # remove last newline
    tls_san_section=\$(echo "\${tls_san_section}" | sed '$ s/.$//')

    # download the RKE installer
    curl -sfL https://get.rke2.io -o install.sh
    chmod +x install.sh

    # authenticate as root
    echo "${sudo_password}" | sudo -S su -
    # run as root user
    sudo -i <<- ROOT
        # run the RKE installer
        INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL}" INSTALL_RKE2_VERSION="${RKE2_VERSION}" INSTALL_RKE2_TYPE="server" ./install.sh

        # create RKE config
        cat <<- FOE > /etc/rancher/rke2/config.yaml
tls-san:
\${tls_san_section}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
disable: rke2-ingress-nginx
write-kubeconfig-mode: 644
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
FOE

        # restart RKE2 server service
        systemctl restart rke2-server.service

        # return the token value
        token=\$(cat /var/lib/rancher/rke2/server/node-token)
        echo "\${token}"
ROOT
EOF
)

# extract master node 1 token
token=$(echo "${configure_master}" | tail -n 1)

# configure the rest of the master nodes
for ((i = 1; i < "${#master_hostnames[@]}"; i++)); do
    master_hostname="${master_hostnames[${i}]}"
    echo "Configuring master: ${master_hostname}"

    # remote login into master node
    ssh "${service_user}@${master_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # variables
        master_hostnames=(${master_hostnames[@]})

        # construct the tls-san section dynamically
        tls_san_section=""
        for hostname in "\${master_hostnames[@]}"; do
            tls_san_section+="  - \${hostname}"\$'\n'
        done
        # remove last newline
        tls_san_section=\$(echo "\${tls_san_section}" | sed '$ s/.$//')

        # authenticate as root
        echo "${sudo_password}" | sudo -S su -
        # run as root user
        sudo -i <<- ROOT
            # download the RKE installer
            curl -sfL https://get.rke2.io -o install.sh
            chmod +x install.sh

            # run the RKE installer
            INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL}" INSTALL_RKE2_VERSION="${RKE2_VERSION}" INSTALL_RKE2_TYPE="server" ./install.sh

            # create RKE config
            cat <<- FOE > /etc/rancher/rke2/config.yaml
server: https://\${master_hostnames[0]}:9345
token: ${token}
write-kubeconfig-mode: "0644"
tls-san:
\${tls_san_section}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
disable: rke2-ingress-nginx
FOE

            # start and enable RKE2 server service
            systemctl enable --now rke2-server.service
ROOT
EOF
done

# configure the worker nodes
for ((i = 0; i < "${#worker_hostnames[@]}"; i++)); do
    worker_hostname="${worker_hostnames[${i}]}"
    echo "Configuring worker: ${worker_hostname}"

    # remote login into worker node
    ssh "${service_user}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # authenticate as root
        echo "${sudo_password}" | sudo -S su -
        # run as root user
        sudo -i <<- ROOT
            # download the RKE installer
            curl -sfL https://get.rke2.io -o install.sh
            chmod +x install.sh

            # run the RKE installer
            INSTALL_RKE2_CHANNEL="${RKE2_CHANNEL}" INSTALL_RKE2_VERSION="${RKE2_VERSION}" INSTALL_RKE2_TYPE="agent" ./install.sh

            # create RKE config
            cat <<- FOE > /etc/rancher/rke2/config.yaml
server: https://${master_hostnames[0]}:9345
token: ${token}
FOE

            # start and enable RKE2 agent service
            systemctl enable --now rke2-agent.service
ROOT
EOF
done

# create kubeconfig folder
mkdir -p ~/.kube

# copy kubeconfig file from master node 1
ssh "${service_user}@${master_hostnames[0]}" -p "${SSH_PORT}" "echo '${sudo_password}' | sudo -S cat '/etc/rancher/rke2/rke2.yaml'" > ~/.kube/config

# replace localhost with master node 1 hostname
sed -i "s/127\.0\.0\.1/${master_hostnames[0]}/g" ~/.kube/config

# label worker nodes as worker
for ((i = 0; i < "${#worker_hostnames[@]}"; i++)); do
    kubectl label node "${worker_hostnames[${i}]}" node-role.kubernetes.io/worker=worker
done

# check cluster status
kubectl get nodes -o wide