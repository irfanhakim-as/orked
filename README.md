# Orked

## About

**O-tomated RKE Distribution (Orked)** is a collection of scripts that aims to easily and reliably set up a production-ready Kubernetes cluster based on RKE2, with Longhorn storage, that is highly performant and efficient.

## Directory

- [Orked](#orked)
  - [About](#about)
  - [Directory](#directory)
  - [Prerequisites](#prerequisites)
    - [Hardware](#hardware)
    - [Configuration](#configuration)
  - [Installation](#installation)
    - [Login node](#login-node)
    - [Passwordless access](#passwordless-access)
    - [Kubernetes node configuration](#kubernetes-node-configuration)
    - [RKE2 installation](#rke2-installation)
    - [Longhorn storage](#longhorn-storage)
    - [MetalLB load balancer](#metallb-load-balancer)
    - [Ingress NGINX](#ingress-nginx)
    - [Cert-Manager](#cert-manager)
    - [SMB storage (Optional)](#smb-storage-optional)
  - [Helper scripts](#helper-scripts)
    - [Update connection](#update-connection)
    - [Hostname resolution](#hostname-resolution)
    - [Toggle SELinux](#toggle-selinux)
  - [Additional resources](#additional-resources)
    - [Adding environment variables](#adding-environment-variables)

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

---

## Installation

For details on how to use each of these scripts and what they are for, please refer to the following subsections. Please also ensure that you have met Orked's [prerequisites](#prerequisites) before proceeding.

> [!IMPORTANT]  
> It is highly recommended that you adhere to the following installation steps in the presented order.

### Login node

- This script sets up the Login node by installing various dependencies and tools required for managing and interacting with the Kubernetes cluster.

- From the root of the repository, run the [script](./scripts/login/login.sh) on the Login node:

    ```sh
    bash ./scripts/login/login.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |

### Passwordless access

> [!IMPORTANT]  
> This script requires the `PasswordAuthentication` SSH configuration option to be set to `yes` on all of the Kubernetes nodes in the cluster. They may be turned back to `no` after the script completes.

- This script sets up the Login node for passwordless SSH access to all the nodes in the Kubernetes cluster.

- From the root of the repository, run the [script](./scripts/passwordless.sh) on the Login node:

    ```sh
    bash ./scripts/passwordless.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `SSH_KEY_TYPE` | The SSH key type to generate and use on the Login node. | `ecdsa` | `ed25519` |
    | `PUBLIC_SSH_KEY` | The path to the public SSH key to use on the Login node. | `/home/myuser/.ssh/mykey.pub` | `${HOME}/.ssh/id_${SSH_KEY_TYPE}.pub` |

### Kubernetes node configuration

- This script configures the to-be Kubernetes nodes by setting up networking, disabling unnecessary services and functionalities, and performing several other best practice configurations for Kubernetes in a production environment.

- From the root of the repository, run the [script](./scripts/configure.sh) on the Login node:

    ```sh
    bash ./scripts/configure.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |

### RKE2 installation

- [RKE2](https://docs.rke2.io), also known as RKE Government, is Rancher's next-generation Kubernetes distribution. It is a fully conformant Kubernetes distribution that focuses on security and compliance within the U.S. Federal Government sector.

- This script automates the installation and configuration of RKE2 on the Master and Worker nodes. It performs all the necessary steps to set up a fully functional RKE2 cluster.

- From the root of the repository, run the [script](./scripts/rke.sh) on the Login node:

    ```sh
    bash ./scripts/rke.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `RKE2_CHANNEL` | The channel to use for fetching the RKE2 download URL. | `latest` | `stable` |
    | `RKE2_VERSION` | The version of RKE2 to download and install. | `v1.30.1+rke2r1` | `v1.25.15+rke2r2` |

### Longhorn storage

- [Longhorn](https://longhorn.io) is a lightweight, reliable, and powerful distributed block storage system for Kubernetes.

- This script automates the installation and configuration of Longhorn on the Worker nodes, and setting up each of their dedicated virtual disk. It ensures that all required components and configurations are applied correctly for setting up the Longhorn storage.

- From the root of the repository, run the [script](./scripts/longhorn.sh) on the Login node:

    ```sh
    bash ./scripts/longhorn.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |

### MetalLB load balancer

- [MetalLB](https://metallb.universe.tf) is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols.

- This script automates the deployment and configuration of MetalLB using a set of predefined configurations and user-reserved private IP addresses.

- From the root of the repository, run the [script](./scripts/metallb.sh) on the Login node:

    ```sh
    bash ./scripts/metallb.sh
    ```

### Ingress NGINX

- [Ingress NGINX Controller](https://github.com/kubernetes/ingress-nginx) is an Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer. Ingress in Kubernetes is an API object that manages external access to the services in a cluster, typically HTTP. It may also provide load balancing, SSL termination and name-based virtual hosting.

- This script automates the deployment and configuration of the Ingress NGINX Controller on a Kubernetes cluster, specifically tailored for bare metal environments.

- From the root of the repository, run the [script](./scripts/ingress.sh) on the Login node:

    ```sh
    bash ./scripts/ingress.sh
    ```

### Cert-Manager

> [!IMPORTANT]  
> This requires a registered Cloudflare account which could be [acquired](https://dash.cloudflare.com/sign-up) for free.

- [cert-manager](https://cert-manager.io) is a powerful and extensible X.509 certificate controller for Kubernetes and OpenShift workloads. It will obtain certificates from a variety of Issuers, both popular public Issuers as well as private Issuers, and ensure the certificates are valid and up-to-date, and will attempt to renew certificates at a configured time before expiry.

- This script automates the setup and configuration of cert-manager in a Kubernetes cluster, using [Cloudflare](https://www.cloudflare.com) for DNS validation. It ensures that cert-manager is correctly installed, configured, and integrated with Cloudflare for issuing [Let's Encrypt](https://letsencrypt.org) certificates.

- From the root of the repository, run the [script](./scripts/cert-manager.sh) on the Login node:

    ```sh
    bash ./scripts/cert-manager.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `CF_EMAIL` | The Cloudflare user email used for API authentication. | `myuser@example.com` | - |
    | `CF_API_KEY` | The Cloudflare API key used for API authentication. | `mycloudflareapikey` | - |

### SMB storage (Optional)

> [!IMPORTANT]  
> This requires an existing SMB server to be configured for use on the Worker nodes.

- [SMB CSI Driver for Kubernetes](https://github.com/kubernetes-csi/csi-driver-smb) allows Kubernetes to access SMB server on both Linux and Windows nodes. It requires existing and already configured SMB server, and supports dynamic provisioning of Persistent Volumes via Persistent Volume Claims by creating a new sub directory under the SMB server.

- This script automates the configuration of SELinux settings on Worker nodes, the installation of the SMB CSI Driver, and the setup of the SMB storage in a Kubernetes cluster. It ensures that all necessary components and configurations are applied correctly for integrating SMB storage.

- From the root of the repository, run the [script](./scripts/smb.sh) on the Login node:

    ```sh
    bash ./scripts/smb.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `SMB_USER` | The username of the SMB user account. | `mysmbuser` | - |
    | `SMB_PASSWD` | The password of the SMB user account. | `mysmbpassword` | - |

---

## Helper scripts

These helper scripts are not required for installing and setting up the Kubernetes cluster, but may be helpful in certain situations. Use them as you see fit.

### Update connection

- This script configures the network settings on the node it runs on, specifically focusing on setting a static IPv4 address and updating the node's local hostname.

- From the root of the repository, run the [script](./helpers/update-connection.sh) on the intended node:

    ```sh
    bash ./helpers/update-connection.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `IFCFG_CONFIG` | The full path to the network configuration file. | `/etc/netplan/00-installer-config.yaml` | `/etc/sysconfig/network-scripts/ifcfg-${IFCFG_INTERFACE}` |
    | `IFCFG_DNS1` | The primary DNS server IP address. | `8.8.8.8` | `1.1.1.1` |
    | `IFCFG_DNS2` | The secondary DNS server IP address. | `8.8.4.4` | `8.8.8.8` |

    Please refer to the content of the script for the full list of supported environment variables.

### Hostname resolution

- This script automates the process of updating the hostname entries on all nodes in the cluster, including the Login node. It ensures that all nodes in the cluster have the necessary name resolution between nodes.

- From the root of the repository, run the [script](./helpers/hostname-resolution.sh) on the Login node:

    ```sh
    bash ./helpers/hostname-resolution.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |

### Toggle SELinux

- [Security-Enhanced Linux (SELinux)](https://www.redhat.com/en/topics/linux/what-is-selinux) is a security architecture for Linux systems that allows administrators to have more control over who can access the system. It was originally developed by the United States National Security Agency (NSA) as a series of patches to the Linux kernel using Linux Security Modules (LSM).

- This script toggles the SELinux enforcement status on Worker nodes, which may be required for certain rare instances.

- From the root of the repository, run the [script](./helpers/selinux-toggle.sh) on the Login node:

    ```sh
    bash ./helpers/selinux-toggle.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |

---

## Additional resources

### Adding environment variables

To supply environment variable values to a script, simply prepend the command to run the script with the environment variable name and its value:

```sh
ENV_VAR_NAME=ENV_VAR_VALUE bash <script>
```

> [!NOTE]  
> Supply as many `ENV_VAR_NAME` and `ENV_VAR_VALUE` pairs as you need and replace `<script>` with the actual path to the script.

Alternatively, instead of setting environment variables individually on a per-script basis, you can set them globally, temporarily by exporting them in your current shell session:

```sh
export ENV_VAR_NAME=ENV_VAR_VALUE
```
