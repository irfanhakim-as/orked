#!/bin/bash

# download nginx-ingress manifest
curl -o ~/nginx-ingress.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/baremetal/deploy.yaml

# replace NodePort with LoadBalancer
sed -i 's/type: NodePort/type: LoadBalancer/g' ~/nginx-ingress.yaml

# install nginx ingress
kubectl apply -f ~/nginx-ingress.yaml

# wait until no pods are pending
bash ./utils.sh --wait-for-pods ingress-nginx

# get ingress-nginx-controller service
kubectl get svc ingress-nginx-controller -n ingress-nginx