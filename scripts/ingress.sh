#!/bin/bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# dependency path
DEP_PATH="${SOURCE_DIR}/../deps"

# download nginx-ingress manifest
# source: https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/baremetal/deploy.yaml
cp -f "${DEP_PATH}/ingress/deploy.yaml" ~/nginx-ingress.yaml

# replace NodePort with LoadBalancer
sed -i 's/type: NodePort/type: LoadBalancer/g' ~/nginx-ingress.yaml

# install nginx ingress
kubectl apply -f ~/nginx-ingress.yaml

# wait until no pods are pending
bash "${SOURCE_DIR}/utils.sh" --wait-for-pods ingress-nginx

# get ingress-nginx-controller service
kubectl get svc ingress-nginx-controller -n ingress-nginx