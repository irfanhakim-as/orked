# orked

## Prerequisites

- All nodes must be running Rocky Linux 8.6>
- At least a single Login node, Master node and Worker node
- All worker nodes must have a single virtual disk available for Longhorn storage separate from the OS disk
- All nodes must be given a static IP address
- The login node must have hostname resolution for all nodes in the cluster

## Scripts

| Script | Description | Target |
| ------ | ----------- | ------ |
| `passwordless.sh` | Setup passwordless login from Login node | Worker Nodes |
| `configure.sh` | Kubernetes node configuration | Kubernetes Nodes (Master & Worker) |
| `login.sh` | Login node configuration | Login Node |
| `rke.sh` | RKE installation and configuration | Kubernetes Nodes (Master & Worker) and Login Node |
| `longhorn.sh` | Longhorn storage installation | Login Node and Worker Nodes |
