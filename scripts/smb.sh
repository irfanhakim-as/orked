#!/bin/bash

# get sudo password
echo "Enter sudo password:"
sudo_password=$(bash ./utils.sh --get-password)

# get smb credentials
smb_username=$(bash ./utils.sh --get-data "SMB username")
echo "Enter SMB password:"
smb_password=$(bash ./utils.sh --get-password)

# get all hostnames of worker nodes
worker_hostnames=($(bash ./utils.sh --get-values "hostname of worker node"))

# configure SELinux virt_use_samba for each worker node
for ((i = 0; i < ${#worker_hostnames[@]}; i++)); do
  worker_hostname="${worker_hostnames[${i}]}"
  echo "Configuring SELinux virt_use_samba for worker: ${worker_hostname}"

  # remote login into worker node
  ssh "root@${worker_hostname}" 'bash -s' << EOF
    # enable SELinux virt_use_samba
    setsebool -P virt_use_samba 1
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
bash ./utils.sh --wait-for-pods kube-system csi-smb

# create a secret for the SMB share if not already created
if ! kubectl get secret smbcreds --namespace default &> /dev/null; then
  kubectl create secret generic smbcreds --from-literal username="${smb_username}" --from-literal password="${smb_password}" --namespace default
fi

# install smb storage class
# https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/deploy/example/storageclass-smb.yaml
kubectl apply -f ../manifests/storageclass-smb.yaml

# wait for smb to be ready
# TODO: not sure what to wait for to determine if smb storageclass is ready
sleep 10

# check storage class
kubectl get sc