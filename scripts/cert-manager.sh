#!/bin/bash

# get user email for let's encrypt
user_email=$(bash ./utils.sh --get-data "user email")

# get cloudflare api key
cloudflare_api_key=$(bash ./utils.sh --get-secret "Cloudflare API key")

# add helm repo
if ! helm repo list | grep -q "jetstack"; then
  helm repo add jetstack https://charts.jetstack.io
fi

# update helm repo
helm repo update jetstack

# install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.11.0 --set installCRDs=true --wait

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

# copy cloudflare secrets to home directory
cp -f ../manifests/cloudflare-api-key-secret.yaml ../manifests/cloudflare-api-token-secret.yaml ~

# add cloudflare api key to cloudflare secrets
sed -i "s/{{ CLOUDFLARE_API_KEY }}/${cloudflare_api_key}/g" ~/cloudflare-api-key-secret.yaml
sed -i "s/{{ CLOUDFLARE_API_KEY }}/${cloudflare_api_key}/g" ~/cloudflare-api-token-secret.yaml

# deploy cloudflare secrets
kubectl apply -f ~/cloudflare-api-key-secret.yaml -f ~/cloudflare-api-token-secret.yaml -n cert-manager

# copy letsencrypt-dns-validation.yaml to home directory
cp -f ../manifests/letsencrypt-dns-validation.yaml ~

# replace {{ CLOUDFLARE_USER_EMAIL }} in letsencrypt-dns-validation.yaml
sed -i "s/{{ CLOUDFLARE_USER_EMAIL }}/${user_email}/g" ~/letsencrypt-dns-validation.yaml

# replace {{ CLOUDFLARE_USER_EMAIL }} in letsencrypt-http-validation.yaml
sed -i "s/{{ CLOUDFLARE_USER_EMAIL }}/${user_email}/g" ~/letsencrypt-http-validation.yaml

# apply letsencrypt-dns-validation.yaml and letsencrypt-http-validation.yaml
kubectl apply -f ~/letsencrypt-dns-validation.yaml ~/letsencrypt-http-validation.yaml -n cert-manager

# get cluster issuer
kubectl get clusterissuer