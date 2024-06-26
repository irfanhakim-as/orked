#!/bin/bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# dependency path
DEP_PATH="${SOURCE_DIR}/../deps"

# copy ingress-nginx manifest
# source: https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/baremetal/deploy.yaml
cp -f "${DEP_PATH}/ingress/deploy.yaml" ~/ingress-nginx.yaml

# replace NodePort with LoadBalancer
sed -i 's/type: NodePort/type: LoadBalancer/g' ~/ingress-nginx.yaml

# install nginx ingress
kubectl apply -f ~/ingress-nginx.yaml

# wait until no pods are pending
bash "${SOURCE_DIR}/utils.sh" --wait-for-pods ingress-nginx

# get ingress-nginx-controller service
kubectl get svc ingress-nginx-controller -n ingress-nginx