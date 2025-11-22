#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SOURCE_DIR}/utils.sh"

# print title
print_title "HAproxy load balancer"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
# export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
export SUDO_PASSWD=$(printf '%q' "${SUDO_PASSWD}")
SSH_PORT="${SSH_PORT:-"22"}"
LB_NODE="${LB_NODE}"
LB_NODE_IP="${LB_NODE_IP}"
MASTER_NODES=(${MASTER_NODES:-$(get_values "hostname of master node")})

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "LB_NODE"
    "LB_NODE_IP"
    "MASTER_NODES"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# validate number of master nodes
if [ "${#MASTER_NODES[@]}" -lt 1 ]; then
    echo "ERROR: There must be at least 1 master node"
    exit 1
fi

# build haproxy backend servers config for api servers and supervisors
api_backend_servers=""
supervisor_backend_servers=""
for ((i = 0; i < "${#MASTER_NODES[@]}"; i++)); do
    master_hostname="${MASTER_NODES[${i}]}"
    api_backend_servers+="    server master${i} ${master_hostname}:6443 check"$'\n'
    supervisor_backend_servers+="    server master${i} ${master_hostname}:9345 check"$'\n'
done
# remove trailing newline
api_backend_servers="${api_backend_servers%$'\n'}"
supervisor_backend_servers="${supervisor_backend_servers%$'\n'}"

# build haproxy config
haproxy_config=$(cat <<- EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    # stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# rke2 api server (kube-apiserver)
frontend rke2-api
    bind *:6443
    mode tcp
    option tcplog
    default_backend rke2-servers

backend rke2-servers
    mode tcp
    balance roundrobin
    option tcp-check
${api_backend_servers}

# rke2 supervisor (for joining nodes)
frontend rke2-supervisor
    bind *:9345
    mode tcp
    option tcplog
    default_backend rke2-supervisor-backend

backend rke2-supervisor-backend
    mode tcp
    balance roundrobin
    option tcp-check
${supervisor_backend_servers}

# stats page (optional)
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats realm HAProxy\ Statistics
EOF
)

# encode the haproxy config for secure transfer
haproxy_config_secret="$(echo "${haproxy_config}" | base64)"

#############################################################################################################

# configure haproxy on loadbalancer
echo "Configuring HAproxy loadbalancer: ${LB_NODE}"
ssh "${SERVICE_USER}@${LB_NODE}" -p "${SSH_PORT}" 'bash -s' <<- EOF
    # authenticate as root
    echo ${SUDO_PASSWD} | sudo -S su - > /dev/null 2>&1
    # run as root user
    sudo -i <<- ROOT
        # install haproxy
        dnf install -y haproxy

        # backup existing config
        [ ! -f /etc/haproxy/haproxy.cfg.bak ] && cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

        # decode and write updated haproxy config
        echo "${haproxy_config_secret}" | base64 --decode > /etc/haproxy/haproxy.cfg

        # configure selinux to allow haproxy ports
        semanage port -a -t http_port_t -p tcp 6443
        semanage port -a -t http_port_t -p tcp 9345
        semanage port -a -t http_port_t -p tcp 8404

        # configure firewall to allow haproxy ports
        firewall-cmd --add-port=6443/tcp --permanent
        firewall-cmd --add-port=9345/tcp --permanent
        firewall-cmd --add-port=8404/tcp --permanent
        firewall-cmd --reload

        # start and enable haproxy service
        systemctl enable --now haproxy.service

        # check haproxy service status
        systemctl status haproxy.service --no-pager
ROOT
EOF