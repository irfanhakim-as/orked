#!/bin/bash

# get some required values from user
user_email=$(bash ./utils.sh --get-data "user email")
cloudflare_api_key=$(bash ./utils.sh --get-secret "Cloudflare API key")

# add helm repo
if ! helm repo list | grep -q "jetstack"; then
  helm repo add jetstack https://charts.jetstack.io
fi

# update helm repo
helm repo update jetstack

# install cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.11.0 --set installCRDs=true

# wait until no pods are pending
bash ./utils.sh --wait-for-pods cert-manager

# patch the cert-manager deployment to add dnsConfig: options: - name: ndots value: "1"
kubectl patch deployment cert-manager -n cert-manager --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/dnsConfig",
    "value": {
      "options": [
        {
          "name": "ndots",
          "value": "1"
        }
      ]
    }
  }
]'

# copy cloudflare-api-key-secret.yaml to home directory
cp -f ../manifests/cloudflare-api-key-secret.yaml ~

# add cloudflare api key to cloudflare-api-key-secret.yaml
sed -i "s/{{ CLOUDFLARE_API_KEY }}/${cloudflare_api_key}/g" ~/cloudflare-api-key-secret.yaml

# apply cloudflare-api-key-secret.yaml
kubectl apply -f ~/cloudflare-api-key-secret.yaml -n cert-manager

# copu letsencrypt-dns-validation.yaml to home directory
cp -f ../manifests/letsencrypt-dns-validation.yaml ~

# replace {{ CLOUDFLARE_USER_EMAIL }} in letsencrypt-dns-validation.yaml
sed -i "s/{{ CLOUDFLARE_USER_EMAIL }}/${user_email}/g" ~/letsencrypt-dns-validation.yaml

# apply letsencrypt-dns-validation.yaml
kubectl apply -f ~/letsencrypt-dns-validation.yaml -n cert-manager

# get cluster issuer
kubectl get clusterissuer