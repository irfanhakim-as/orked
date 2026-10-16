#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/.."
SCRIPT_DIR="${ROOT_DIR}/scripts"
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SCRIPT_DIR}/utils.sh"

# restore longhorn node scheduling and eviction to their original state
function restore_longhorn_node() {
    local node_name="${1}"
    local allow_scheduling="${2}"
    local eviction_requested="${3}"
    kubectl -n longhorn-system patch node.longhorn.io "${node_name}" \
        --type=merge -p "{\"spec\":{\"allowScheduling\":${allow_scheduling},\"evictionRequested\":${eviction_requested}}}"
}

# print title
print_title "stop cluster"

# variables
SERVICE_USER="${SERVICE_USER:-"$(get_data "service user account")"}"
# export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
CLEAN_SUDO_PASSWD=$(printf '%q' "${SUDO_PASSWD}")
SSH_PORT="${SSH_PORT:-"22"}"
MASTER_NODES=(${MASTER_NODES:-$(get_values "hostname of master node")})
WORKER_NODES=(${WORKER_NODES:-$(get_values "hostname of worker node")})
SHUTDOWN_NODES="$(get_bool "shutdown all nodes")"; echo
DRAIN_OPTS="${DRAIN_OPTS:+ ${DRAIN_OPTS}}"
LONGHORN_EVACUATE="${LONGHORN_EVACUATE:-"true"}"
LONGHORN_EVACUATION_TIMEOUT="${LONGHORN_EVACUATION_TIMEOUT:-"1800"}"

# env variables
env_variables=(
    "SERVICE_USER"
    "SUDO_PASSWD"
    "SSH_PORT"
    "MASTER_NODES"
    "WORKER_NODES"
    "SHUTDOWN_NODES"
    "DRAIN_OPTS"
    "LONGHORN_EVACUATE"
    "LONGHORN_EVACUATION_TIMEOUT"
)

# optional variables
opt_variables=(
    "MASTER_NODES"
    "WORKER_NODES"
    "DRAIN_OPTS"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}" "${opt_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# enable longhorn replica evacuation if other ready workers remain
evacuate_longhorn=false
if [ "${LONGHORN_EVACUATE}" == "true" ] && kubectl get crd nodes.longhorn.io &> /dev/null; then
    remaining_workers=0
    while IFS= read -r node; do
        in_list=false
        for w in "${WORKER_NODES[@]}"; do
            if [ "${node}" == "${w}" ]; then
                in_list=true
                break
            fi
        done
        [ "${in_list}" == "false" ] && remaining_workers=$((remaining_workers + 1))
    done < <(kubectl get nodes --no-headers 2>/dev/null | grep " Ready" | grep -v "control-plane\|master" | awk '{print $1}')
    [ "${remaining_workers}" -gt 0 ] && evacuate_longhorn=true
fi

if [ "${evacuate_longhorn}" == "true" ]; then
    echo "Maintenance stop: Longhorn replicas will be evacuated before drain"
else
    echo "Skipping Longhorn replica evacuation"
fi

# flag all worker nodes as unschedulable
# for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
#     worker_hostname="${WORKER_NODES[${i}]}"
#     echo "Cordoning worker: ${worker_hostname}"
#     kubectl cordon "${worker_hostname}"
# done

# drain all worker nodes
for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
    worker_hostname="${WORKER_NODES[${i}]}"
    # flag worker node as unschedulable
    echo "Cordoning worker: ${worker_hostname} in 5s..."
    sleep 5 && kubectl cordon "${worker_hostname}"
    # evacuate longhorn replicas before drain for maintenance stops
    if [ "${evacuate_longhorn}" == "true" ]; then
        echo "Evacuating Longhorn replicas from: ${worker_hostname}"
        # save original longhorn node state
        lh_allow_scheduling=$(kubectl -n longhorn-system get node.longhorn.io "${worker_hostname}" -o jsonpath='{.spec.allowScheduling}' 2>/dev/null)
        lh_eviction_requested=$(kubectl -n longhorn-system get node.longhorn.io "${worker_hostname}" -o jsonpath='{.spec.evictionRequested}' 2>/dev/null)
        if [ -z "${lh_allow_scheduling}" ] || [ -z "${lh_eviction_requested}" ]; then
            echo "ERROR: Could not retrieve Longhorn node state for ${worker_hostname}"
            kubectl uncordon "${worker_hostname}"
            exit 1
        fi
        echo "Longhorn node state for ${worker_hostname}: allowScheduling=${lh_allow_scheduling}, evictionRequested=${lh_eviction_requested}"
        # enable longhorn maintenance mode
        if ! kubectl -n longhorn-system patch node.longhorn.io "${worker_hostname}" \
            --type=merge -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'; then
            echo "ERROR: Failed to enable Longhorn maintenance mode for ${worker_hostname}"
            kubectl uncordon "${worker_hostname}"
            exit 1
        fi
        # wait for replicas to leave the node
        elapsed=0
        while kubectl -n longhorn-system get replicas.longhorn.io \
            -o jsonpath="{.items[?(@.spec.nodeID=='${worker_hostname}')].metadata.name}" \
            2>/dev/null | grep -q .; do
            if [ "${elapsed}" -ge "${LONGHORN_EVACUATION_TIMEOUT}" ]; then
                echo "ERROR: Timed out waiting for Longhorn replicas to evacuate from ${worker_hostname}"
                restore_longhorn_node "${worker_hostname}" "${lh_allow_scheduling}" "${lh_eviction_requested}" || echo "WARNING: Failed to restore Longhorn scheduling for ${worker_hostname} - please restore it manually!"
                kubectl uncordon "${worker_hostname}"
                exit 1
            fi
            echo "Waiting for replicas to evacuate from ${worker_hostname}..."
            sleep 10
            elapsed=$((elapsed + 10))
        done
        echo "Longhorn replicas evacuated from ${worker_hostname}"
    fi
    # drain worker node
    echo "Draining worker: ${worker_hostname}"
    kubectl drain "${worker_hostname}" --force --delete-emptydir-data --ignore-daemonsets --timeout 0"${DRAIN_OPTS}"
    # kill worker node
    echo "Killing worker: ${worker_hostname}"
    ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # kill all kubernetes processes
        echo ${CLEAN_SUDO_PASSWD} | sudo -S rke2-killall.sh
EOF
    # wait for worker node to be dead
    wait_for_node_readiness "${worker_hostname}" "false"
    # shut down worker nodes if specified
    if [ "${SHUTDOWN_NODES}" == "true" ]; then
        echo "Shutting down worker: ${worker_hostname} in 5s..."
        sleep 5
        # shut down worker node
        ssh "${SERVICE_USER}@${worker_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
            # shutdown the node
            echo ${CLEAN_SUDO_PASSWD} | sudo -S shutdown now
EOF
    fi
    # restore longhorn scheduling after maintenance
    if [ "${evacuate_longhorn}" == "true" ]; then
        echo "Restoring Longhorn scheduling for: ${worker_hostname}"
        restore_longhorn_node "${worker_hostname}" "${lh_allow_scheduling}" "${lh_eviction_requested}" || echo "WARNING: Failed to restore Longhorn scheduling for ${worker_hostname} - please restore it manually!"
    fi
    # flag worker node as schedulable
    echo "Uncordoning worker: ${worker_hostname}"
    kubectl uncordon "${worker_hostname}"
done

# flag all worker nodes as schedulable
# for ((i = 0; i < "${#WORKER_NODES[@]}"; i++)); do
#     worker_hostname="${WORKER_NODES[${i}]}"
#     echo "Uncordoning worker: ${worker_hostname}"
#     kubectl uncordon "${worker_hostname}"
# done

# stop master nodes in reverse order
for ((i = "${#MASTER_NODES[@]}" - 1; i >= 0; i--)); do
    master_hostname="${MASTER_NODES[${i}]}"
    # kill master node
    echo "Killing master: ${master_hostname}"
    # remote login into master node
    ssh "${SERVICE_USER}@${master_hostname}" -p "${SSH_PORT}" 'bash -s' <<- EOF
        # kill all kubernetes processes
        echo ${CLEAN_SUDO_PASSWD} | sudo -S rke2-killall.sh
        # shut down master nodes if specified
        if [ "${SHUTDOWN_NODES}" == "true" ]; then
            echo "Shutting down master: ${master_hostname} in 5s..."
            sleep 5
            echo ${CLEAN_SUDO_PASSWD} | sudo -S shutdown now
        fi
EOF
done