#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEP_PATH="${SOURCE_DIR}/../deps"

# source project files
source "${SOURCE_DIR}/utils.sh"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get service user account
service_user=$(get_data "service user account")

# get sudo password
echo "Enter sudo password:"
sudo_password=$(get_password)

# get smb credentials
smb_username=$(get_data "SMB username")
echo "Enter SMB password:"
smb_password=$(get_password)

# get all hostnames of worker nodes
worker_hostnames=($(get_values "hostname of worker node"))

# configure SELinux virt_use_samba for each worker node
for ((i = 0; i < "${#worker_hostnames[@]}"; i++)); do
  worker_hostname="${worker_hostnames[${i}]}"
  echo "Configuring SELinux virt_use_samba for worker: ${worker_hostname}"

  # remote login into worker node
  ssh "${service_user}@${worker_hostname}" 'bash -s' <<-EOF
    # enable SELinux virt_use_samba
    echo "${sudo_password}" | sudo -S bash -c "setsebool -P virt_use_samba 1"
EOF
done

# add helm repo
if ! helm repo list | grep -q "csi-driver-smb"; then
  helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
fi

# update helm repo
helm repo update csi-driver-smb

# install csi-driver-smb
helm upgrade --install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace kube-system --create-namespace --version v1.14.0 --wait

# wait until no pods are pending
wait_for_pods kube-system csi-smb

# create a secret for the SMB share if not already created
if ! kubectl get secret smbcreds --namespace default &> /dev/null; then
  kubectl create secret generic smbcreds --from-literal username="${smb_username}" --from-literal password="${smb_password}" --namespace default
fi

# install smb storage class
# source: https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/deploy/example/storageclass-smb.yaml
kubectl apply -f "${DEP_PATH}/smb/storageclass-smb.yaml"

# wait for smb to be ready
# TODO: not sure what to wait for to determine if smb storageclass is ready
sleep 10

# check storage class
kubectl get sc