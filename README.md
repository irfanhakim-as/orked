# orked

## Overview
Simple scripts to setup a Kubernetes cluster with Longhorn storage on Rocky Linux 8.6 using RKE2.

## Prerequisites

- All nodes must be running Rocky Linux 8.6>
- At least a single Login node, Master node and Worker node
- All worker nodes must have a single virtual disk available for Longhorn storage separate from the OS disk
- All nodes must be given a static IP address
- The login node must have hostname resolution for all nodes in the cluster
- At least one reserved private IPv4 address for the load balancer

## Scripts

| Script | Description | Target |
| ------ | ----------- | ------ |
| `passwordless.sh` | Setup passwordless login from Login node | Worker Nodes |
| `configure.sh` | Kubernetes node configuration | Kubernetes Nodes (Master & Worker) |
| `login.sh` | Login node configuration | Login Node |
| `rke.sh` | RKE installation and configuration | Kubernetes Nodes (Master & Worker) and Login Node |
| `longhorn.sh` | Longhorn storage installation | Login Node and Worker Nodes |
| `metallb.sh` | MetalLB load balancer installation | Login Node |
| `ingress.sh` | NGINX Ingress installation | Login Node |
| `cert-manager.sh` | Cert-Manager installation | Login Node |
