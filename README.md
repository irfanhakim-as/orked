# orked

## Overview

Simple scripts to setup a Kubernetes cluster with Longhorn storage on Rocky Linux 8.6 using RKE2.

## Prerequisites

### Hardware

- All nodes must be running Rocky Linux 8.6+
- At least a single Login node, Master node and Worker node
- All Worker nodes must have a single virtual disk available for Longhorn storage in addition to the OS disk
- At least one _reserved_ private IPv4 address for the load balancer

### Configuration

- All nodes must be given a static IP address
- The Login node must have hostname resolution to all nodes in the cluster
- All Master nodes must have hostname resolution to all Master nodes
- All Worker nodes must have hostname resolution to the Primary Master node

## Scripts

| Script | Description | Target |
| ------ | ----------- | ------ |
| [`passwordless.sh`](./scripts/passwordless.sh) | Setup passwordless login from Login node | Kubernetes Nodes (Master & Worker) |
| [`configure.sh`](./scripts/configure.sh) | Kubernetes node configuration | Kubernetes Nodes (Master & Worker) |
| [`login.sh`](./scripts/login/login.sh) | Login node configuration | Login Node |
| [`rke.sh`](./scripts/rke.sh) | RKE installation and configuration | Kubernetes Nodes (Master & Worker) and Login Node |
| [`longhorn.sh`](./scripts/longhorn.sh) | Longhorn storage installation | Login Node and Worker Nodes |
| [`smb.sh`](./scripts/smb.sh) | SMB storage installation | Login Node and Worker Nodes |
| [`metallb.sh`](./scripts/metallb.sh) | MetalLB load balancer installation | Login Node |
| [`ingress.sh`](./scripts/ingress.sh) | NGINX Ingress installation | Login Node |
| [`cert-manager.sh`](./scripts/cert-manager.sh) | Cert-Manager installation | Login Node |

## Helpers

| Script | Description | Target |
| ------ | ----------- | ------ |
| [`update-connection.sh`](./helpers/update-connection.sh) | Setup network connection and Static IP | All Nodes |
| [`selinux-toggle.sh`](./helpers/selinux-toggle.sh) | Toggle SELinux between `enforcing` and `permissive` | Worker Nodes |
