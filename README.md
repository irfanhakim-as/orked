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
  - [Hardware requirements](#hardware-requirements)
    - [Login node](#login-node)
    - [Master node](#master-node)
    - [Worker node](#worker-node)
  - [Installation](#installation)
    - [Login node](#login-node-1)
    - [Passwordless access](#passwordless-access)
    - [Hostname resolution](#hostname-resolution)
    - [Kubernetes node configuration](#kubernetes-node-configuration)
    - [RKE2 installation](#rke2-installation)
    - [Longhorn storage](#longhorn-storage)
    - [MetalLB load balancer](#metallb-load-balancer)
    - [Ingress NGINX](#ingress-nginx)
    - [Cert-Manager](#cert-manager)
    - [SMB storage (Optional)](#smb-storage-optional)
  - [Helper scripts](#helper-scripts)
    - [Update connection](#update-connection)
    - [Toggle SELinux](#toggle-selinux)
    - [Resize Longhorn disk](#resize-longhorn-disk)
    - [Stop cluster](#stop-cluster)
  - [Additional resources](#additional-resources)
    - [Adding environment variables](#adding-environment-variables)
    - [Joining additional nodes to an existing cluster](#joining-additional-nodes-to-an-existing-cluster)

---

## Prerequisites

These are a list of items you must fulfill beforehand in order to successfully set up your Kubernetes cluster using Orked.

### Hardware

- All nodes must be running [Rocky Linux](https://rockylinux.org/download) 8.6+
- At least a single [Login node](#login-node), [Master node](#master-node), and [Worker node](#worker-node)
- All Worker nodes must have a single virtual disk available for Longhorn storage in addition to the OS disk

### Configuration

- All nodes are expected to have the same service user account username and sudo password (can be updated post-install)
- All nodes must be given a unique [static IP address and hostname](#update-connection)
- At least one _reserved_ private IPv4 address for the [load balancer](#metallb-load-balancer)

---

## Hardware requirements

This section contains the recommended basic hardware requirements for each of the nodes in the cluster. For additional reference, please refer to the official RKE2 [documentation](https://docs.rke2.io/install/requirements#hardware).

### Login node

- vCPU: `2`
- Memory: `1GB`
- Storage: `15GB`
- Number of nodes: `1`

### Master node

- vCPU: `2`
- Memory: `4GB`
- Storage: `25GB`
- Number of nodes: `1`

### Worker node

- vCPU: `4`
- Memory: `4GB`
- Storage:
  - OS: `50GB`
  - Longhorn: `25GB`
- Number of nodes: `3`

---

## Installation

For details on how to use each of these scripts and what they are for, please refer to the following subsections. Please also ensure that you have met Orked's [prerequisites](#prerequisites) before proceeding.

> [!IMPORTANT]  
> It is highly recommended that you adhere to the following installation steps in the presented order.

---

### Login node

- This script sets up the Login node by installing various dependencies and tools required for managing and interacting with the Kubernetes cluster.

- From the root of the repository, run the [script](./scripts/login/login.sh) on the **Login node**:

    ```sh
    bash ./scripts/login/login.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |

---

### Passwordless access

> [!NOTE]  
> This script requires the `PasswordAuthentication` SSH configuration option to be set to `yes` (default) on all of the Kubernetes nodes in the cluster. They may be updated to `no` after the script completes for better security.

- This script sets up the Login node for passwordless SSH access to all the nodes in the Kubernetes cluster.

- From the root of the repository, run the [script](./scripts/passwordless.sh) on the **Login node**:

    ```sh
    bash ./scripts/passwordless.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `SSH_KEY_TYPE` | The SSH key type to generate and use on the Login node. | `ecdsa` | `ed25519` |
    | `SSH_KEY` | The path to the private SSH key to use on the Login node. | `/home/myuser/.ssh/mykey` | `${HOME}/.ssh/id_${SSH_KEY_TYPE}` |
    | `PUBLIC_SSH_KEY` | The path to the public SSH key to use on the Login node. | `/home/myuser/.ssh/mykey.pub` | `${SSH_KEY}.pub` |
    | `KUBERNETES_NODES_IP` | Space-separated list of IPv4 addresses for Kubernetes nodes. This overrides the `MASTER_NODES_IP` and `WORKER_NODES_IP` environment variables. | `"192.168.1.16 192.168.1.17"` | `("${MASTER_NODES_IP[@]}" "${WORKER_NODES_IP[@]}")` |
    | `MASTER_NODES_IP` | Space-separated list of corresponding IPv4 addresses for Kubernetes master nodes. | `"192.168.1.10 192.168.1.11 192.168.1.12"` | - |
    | `WORKER_NODES_IP` | Space-separated list of corresponding IPv4 addresses for Kubernetes worker nodes. | `"192.168.1.13 192.168.1.14 192.168.1.15"` | - |

---

### Hostname resolution

> [!NOTE]  
> A minimum of limited name resolution between nodes is required for the Kubernetes cluster to be set up and functional.

- This script automates the process of updating the hostname entries on all nodes in the cluster, including the Login node. It ensures that all nodes in the cluster have the necessary name resolution between them.

- From the root of the repository, run the [script](./scripts/hostname-resolution.sh) on the **Login node**:

    ```sh
    bash ./scripts/hostname-resolution.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `MASTER_NODES` | Space-separated list of hostnames for Kubernetes master nodes. | `"orked-master-1.example.com orked-master-2.example.com orked-master-3.example.com"` | - |
    | `MASTER_NODES_IP` | Space-separated list of corresponding IPv4 addresses for Kubernetes master nodes. | `"192.168.1.10 192.168.1.11 192.168.1.12"` | - |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |
    | `WORKER_NODES_IP` | Space-separated list of corresponding IPv4 addresses for Kubernetes worker nodes. | `"192.168.1.13 192.168.1.14 192.168.1.15"` | - |

---

### Kubernetes node configuration

- This script configures the to-be Kubernetes nodes by setting up networking, disabling unnecessary services and functionalities, and performing several other best practice configurations for Kubernetes in a production environment.

- From the root of the repository, run the [script](./scripts/configure.sh) on the **Login node**:

    ```sh
    bash ./scripts/configure.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `KUBERNETES_NODES` | Space-separated list of hostnames for Kubernetes nodes. This overrides the `MASTER_NODES` and `WORKER_NODES` environment variables. | `"orked-master-4.example.com orked-worker-4.example.com"` | `("${MASTER_NODES[@]}" "${WORKER_NODES[@]}")` |
    | `MASTER_NODES` | Space-separated list of hostnames for Kubernetes master nodes. | `"orked-master-1.example.com orked-master-2.example.com orked-master-3.example.com"` | - |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

### RKE2 installation

- [RKE2](https://docs.rke2.io), also known as RKE Government, is Rancher's next-generation Kubernetes distribution. It is a fully conformant Kubernetes distribution that focuses on security and compliance within the U.S. Federal Government sector.

- This script automates the installation and configuration of RKE2 on the Master and Worker nodes. It performs all the necessary steps to set up a fully functional RKE2 cluster.

- From the root of the repository, run the [script](./scripts/rke.sh) on the **Login node**:

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
    | `RKE2_SCRIPT_URL` | The URL to the RKE2 installation script. | `https://example.com/install.sh` | `https://get.rke2.io` |
    | `RKE2_CLUSTER_CIDR` | The CIDR block for pod network. | `10.44.0.0/16` | `10.42.0.0/16` |
    | `RKE2_SERVICE_CIDR` | The CIDR block for cluster services. | `10.45.0.0/16` | `10.43.0.0/16` |
    | `MASTER_NODES` | Space-separated list of hostnames for Kubernetes master nodes. | `"orked-master-1.example.com orked-master-2.example.com orked-master-3.example.com"` | - |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

### Longhorn storage

> [!NOTE]  
> This script requires all Worker nodes to have a dedicated virtual disk attached for use as Longhorn storage. The default virtual disk (`LONGHORN_STORAGE_DEVICE`) value is `/dev/sdb`, you can verify this using the `lsblk` command on each node.

- [Longhorn](https://longhorn.io) is a lightweight, reliable, and powerful distributed block storage system for Kubernetes.

- This script automates the installation and configuration of Longhorn on the Worker nodes, and setting up each of their dedicated virtual disk. It ensures that all required components and configurations are applied correctly for setting up the Longhorn storage.

- From the root of the repository, run the [script](./scripts/longhorn.sh) on the **Login node**:

    ```sh
    bash ./scripts/longhorn.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `LONGHORN_STORAGE_DEVICE` | The Longhorn storage device name. | `/dev/sdc` | `/dev/sdb` |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

### MetalLB load balancer

> [!NOTE]  
> This script requires you to designate at least a single private IP address to be allocated to the MetalLB load balancer.

- [MetalLB](https://metallb.universe.tf) is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols.

- This script automates the deployment and configuration of MetalLB using a set of predefined configurations and user-reserved private IP addresses.

- From the root of the repository, run the [script](./scripts/metallb.sh) on the **Login node**:

    ```sh
    bash ./scripts/metallb.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `METALLB_IP` | Space-separated list of IPv4 addresses to assign to MetalLB for load balancing. | `"192.168.1.100 192.168.1.101"` | - |

---

### Ingress NGINX

- [Ingress NGINX Controller](https://github.com/kubernetes/ingress-nginx) is an Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer. Ingress in Kubernetes is an API object that manages external access to the services in a cluster, typically HTTP. It may also provide load balancing, SSL termination and name-based virtual hosting.

- This script automates the deployment and configuration of the Ingress NGINX Controller on a Kubernetes cluster, specifically tailored for bare metal environments.

- From the root of the repository, run the [script](./scripts/ingress.sh) on the **Login node**:

    ```sh
    bash ./scripts/ingress.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `NGINX_HTTP` | The port used for routing HTTP traffic to the NGINX ingress controller. | `8080` | `80` |
    | `NGINX_HTTPS` | The port used for routing HTTPS traffic to the NGINX ingress controller. | `8443` | `443` |

---

### Cert-Manager

> [!NOTE]  
> This requires a registered Cloudflare account which could be [acquired](https://dash.cloudflare.com/sign-up) for free.

- [cert-manager](https://cert-manager.io) is a powerful and extensible X.509 certificate controller for Kubernetes and OpenShift workloads. It will obtain certificates from a variety of Issuers, both popular public Issuers as well as private Issuers, and ensure the certificates are valid and up-to-date, and will attempt to renew certificates at a configured time before expiry.

- This script automates the setup and configuration of cert-manager in a Kubernetes cluster, using [Cloudflare](https://www.cloudflare.com) for DNS validation. It ensures that cert-manager is correctly installed, configured, and integrated with Cloudflare for issuing [Let's Encrypt](https://letsencrypt.org) certificates.

- From the root of the repository, run the [script](./scripts/cert-manager.sh) on the **Login node**:

    ```sh
    bash ./scripts/cert-manager.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `CF_EMAIL` | The Cloudflare user email used for API authentication. | `myuser@example.com` | - |
    | `CF_API_KEY` | The Cloudflare API key used for API authentication. | `mycloudflareapikey` | - |

---

### SMB storage (Optional)

> [!NOTE]  
> This requires an already existing SMB server for use in the Kubernetes cluster.

- [SMB CSI Driver for Kubernetes](https://github.com/kubernetes-csi/csi-driver-smb) allows Kubernetes to access SMB server on both Linux and Windows nodes. It requires existing and already configured SMB server, and supports dynamic provisioning of Persistent Volumes via Persistent Volume Claims by creating a new sub directory under the SMB server.

- This script automates the configuration of SELinux settings on Worker nodes, the installation of the SMB CSI Driver, and the setup of the SMB storage in a Kubernetes cluster. It ensures that all necessary components and configurations are applied correctly for integrating SMB storage.

- From the root of the repository, run the [script](./scripts/smb.sh) on the **Login node**:

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
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

## Helper scripts

These helper scripts are not necessarily required for installing and setting up the Kubernetes cluster, but may be helpful in certain situations such as helping you meet Orked's [prerequisites](#prerequisites). Use them as you see fit.

---

### Update connection

> [!TIP]  
> It is recommended to use this script first and foremost in order to ensure that each node has been configured with a static IPv4 addres and a unique hostname.

- This script configures the network settings on the node it runs on, specifically focusing on setting a static IPv4 address and updating the node's local hostname.

- From the root of the repository, run the [script](./helpers/update-connection.sh) on **each node**:

    ```sh
    bash ./helpers/update-connection.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `IFCFG_INTERFACE` | The name of the network interface. | `ens192` | - |
    | `IFCFG_IPADDR` | The intended static IPv4 address of the node. | `192.168.1.10` | - |
    | `IFCFG_GATEWAY` | The default gateway IP address. | `192.168.1.1` | - |
    | `IFCFG_DNS1` | The primary DNS server IP address. | `8.8.8.8` | `1.1.1.1` |
    | `IFCFG_DNS2` | The secondary DNS server IP address. | `8.8.4.4` | `8.8.8.8` |
    | `NODE_HOSTNAME` | The intended hostname of the node. | `orked-master-1.example.com` | - |

    Please refer to the content of the script for the full list of supported environment variables.

---

### Toggle SELinux

> [!TIP]  
> SELinux is enabled by default on Rocky Linux. In cases where you have disabled it to perform certain operations that do not support it, it is highly recommended for you to re-enable it after.

- [Security-Enhanced Linux (SELinux)](https://www.redhat.com/en/topics/linux/what-is-selinux) is a security architecture for Linux systems that allows administrators to have more control over who can access the system. It was originally developed by the United States National Security Agency (NSA) as a series of patches to the Linux kernel using Linux Security Modules (LSM).

- This script toggles the SELinux enforcement status on Worker nodes, which may be needed in some cases.

- From the root of the repository, run the [script](./helpers/selinux-toggle.sh) on the **Login node**:

    ```sh
    bash ./helpers/selinux-toggle.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

### Resize Longhorn disk

> [!TIP]  
> This script requires [Longhorn storage](#longhorn-storage) to have already been set up. The Kubernetes cluster must not be operational during this process, it is recommended to [shut down the entire cluster](#stop-cluster) and only boot up the Worker nodes prior to running this script.

- This script automates the process of expanding the size of the Longhorn storage partition on the Worker nodes, assuming the underlying Longhorn disk on each node has already been resized.

- From the root of the repository, run the [script](./helpers/resize-longhorn-disk.sh) on the **Login node**:

    ```sh
    bash ./helpers/resize-longhorn-disk.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `LONGHORN_STORAGE_DEVICE` | The Longhorn storage device name. | `/dev/sdc` | `/dev/sdb` |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

### Stop cluster

> [!TIP]  
> This script is still experimental and should be used with caution.

- This script automates the process of gracefully stopping a Kubernetes cluster by cordoning and draining Worker nodes, stopping all Kubernetes processes, uncordoning the Worker nodes, and stopping all Master nodes (in reverse order). It also comes with the option to shut down all nodes in the entire cluster after they have been stopped.

- From the root of the repository, run the [script](./helpers/stop-cluster.sh) on the **Login node**:

    ```sh
    bash ./helpers/stop-cluster.sh
    ```

- Optional [environment variables](#adding-environment-variables):

    | **Option** | **Description** | **Sample** | **Default** |
    | --- | --- | --- | --- |
    | `SERVICE_USER` | The username of the service user account. | `myuser` | - |
    | `SUDO_PASSWD` | The sudo password of the service user account. | `mypassword` | - |
    | `SSH_PORT` | The SSH port used on the Kubernetes nodes. | `2200` | `22` |
    | `MASTER_NODES` | Space-separated list of hostnames for Kubernetes master nodes. | `"orked-master-1.example.com orked-master-2.example.com orked-master-3.example.com"` | - |
    | `WORKER_NODES` | Space-separated list of hostnames for Kubernetes worker nodes. | `"orked-worker-1.example.com orked-worker-2.example.com orked-worker-3.example.com"` | - |

---

## Additional resources

### Adding environment variables

1. To supply environment variable values to a script, simply prepend the command to run the script with the environment variable name and its value:

    ```sh
    ENV_VAR_NAME=ENV_VAR_VALUE bash <script>
    ```

    > [!NOTE]  
    > Supply as many `ENV_VAR_NAME` and `ENV_VAR_VALUE` pairs as you need and replace `<script>` with the actual path to the script.

2. Alternatively, instead of setting environment variables individually on a per-script basis, you can set them globally (to your Orked repository) by using an `.env` file:

    At the root of the Orked repository, create an `.env` file:

    ```sh
    nano ./.env
    ```

    Add in your environment variable name and value pairs to the file, separated by newlines for each pair like so:

    ```env
    ENV_VAR_NAME=ENV_VAR_VALUE
    ```

    Now when you run any of the installer or helper scripts as is, environment variable values will be sourced accordingly from the `.env` file you have provided.

---

### Joining additional nodes to an existing cluster

> [!NOTE]  
> This guide assumes that you have an existing preconfigured [Login node](#login-node-1) for your Kubernetes cluster set up.

Prepare the additional nodes joining the cluster as you have done for the existing nodes:

1. [Update the network settings](#update-connection) on each **additional node** including setting a static IPv4 address and updating the node's local hostname.

2. Set up the Login node for [passwordless SSH access](#passwordless-access) to all the **additional nodes** in the cluster.

3. [Update the hostname](#hostname-resolution) entries on **all nodes** in the cluster so that they have the necessary name resolution between them.

4. [Configure](#kubernetes-node-configuration) the **additional nodes** by setting up networking, disabling unnecessary services and functionalities, and performing several other best practice configurations.

Once the additional nodes have been prepped and configured, you can proceed to join them to the cluster:

1. [Install and configure RKE2](#rke2-installation) on **all nodes**. This will perform all the necessary steps to set up a fully functional RKE2 cluster including joining the additional nodes to the cluster.

2. If the additional nodes include Worker nodes, [install and configure Longhorn](#longhorn-storage) on the **additional Worker nodes**, and set up their dedicated virtual disk for Longhorn storage.

3. If you require SMB storage and the additional nodes include Worker nodes, [install and configure SMB](#smb-storage-optional) on the **additional Worker nodes**.

Finally, verify that the additional nodes have joined the cluster successfully:

```sh
kubectl get nodes -o wide
```
