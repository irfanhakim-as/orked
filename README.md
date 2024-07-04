# Orked

## Overview

This repository contains installer and helper scripts that can be used to reliably setup a production-ready Kubernetes cluster with Longhorn storage on Rocky Linux 8.6+ using RKE2.

## References

- [RKE2](https://docs.rke2.io)

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
| [`passwordless.sh`](./scripts/passwordless.sh) | Setup passwordless login from Login node | Kubernetes nodes (Master & Worker) |
| [`configure.sh`](./scripts/configure.sh) | Kubernetes node configuration | Kubernetes nodes (Master & Worker) |
| [`login.sh`](./scripts/login/login.sh) | Login node configuration | Login node |
| [`rke.sh`](./scripts/rke.sh) | RKE2 installation and configuration | All nodes |
| [`longhorn.sh`](./scripts/longhorn.sh) | Longhorn storage installation | Login node and Worker nodes |
| [`smb.sh`](./scripts/smb.sh) | SMB storage installation | Login node and Worker nodes |
| [`metallb.sh`](./scripts/metallb.sh) | MetalLB load balancer installation | Login node |
| [`ingress.sh`](./scripts/ingress.sh) | NGINX Ingress installation | Login node |
| [`cert-manager.sh`](./scripts/cert-manager.sh) | Cert-Manager installation | Login node |

## Helpers

| Script | Description | Target |
| ------ | ----------- | ------ |
| [`update-connection.sh`](./helpers/update-connection.sh) | Setup network connection and static IP | All nodes |
| [`selinux-toggle.sh`](./helpers/selinux-toggle.sh) | Toggle SELinux between `enforcing` and `permissive` | Worker nodes |
