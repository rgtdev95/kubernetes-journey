# 🚀 Kubernetes Journey: From Bare Metal to Production

This repository documents my comprehensive journey of building a self-hosted, multi-cluster Kubernetes ecosystem from the ground up. Starting with raw Proxmox VMs, I've progressed through bare-metal cluster provisioning, complex Ansible automation, and finally deployed a Hub-and-Spoke GitOps pipeline using ArgoCD.

## 🏗️ Project Architecture

This project implements a **three-tier Kubernetes infrastructure** running on 6 dedicated Proxmox VMs. It utilizes a strict `kubeadm` bootstrapper rather than lightweight distributions (like K3s/K0s), providing a true enterprise-grade bare-metal experience.

### 🌐 Network Topology
- **Physical Network**: `192.168.0.x/24` (TP-Link ER605 Gateway)
- **VM Network**: `192.168.1.x/24` (Proxmox vmbr0)
- **Local DNS**: `192.168.1.108` (AdGuard Home LXC)

### 🗄️ Cluster Breakdown

| Cluster | Nodes | Role | IP Addresses |
| :--- | :--- | :--- | :--- |
| **central-hub** | 2 | ArgoCD Control Plane | `192.168.1.107`, `192.168.1.102` |
| **prod-cluster** | 2 | Production Workloads | `192.168.1.103`, `192.168.1.104` |
| **dev-cluster** | 2 | Development Workloads | `192.168.1.105`, `192.168.1.106` |

### 🛠️ Core Infrastructure Components
- **Provisioning**: Terraform (Proxmox API via Cloud-Init)
- **Configuration Management**: Ansible
- **Kubernetes Core**: 1.34 via `kubeadm` (Containerd runtime)
- **CNI**: Calico
- **GitOps Engine**: ArgoCD v3.3.6

---

## 💾 Storage & Networking Layers

### Longhorn Block Storage
Dynamic storage provisioning is achieved using **Longhorn v1.8.0**, strictly deployed across all clusters via Helm configuration. Because each cluster consists of exactly 2 nodes (1 CP, 1 Worker), Longhorn was deliberately configured with a `persistence.defaultClassReplicaCount=2` to ensure healthy volume replication without endlessly waiting for a non-existent third node.

### The MetalLB / Ingress Routing Challenge
A major hurdle in this architecture was exposing the internal Kubernetes Services out to the physical Windows LAN network. 
1. **MetalLB** was initially deployed in L2 mode to assign External Virtual IPs (from a pool of `192.168.1.x` addresses) to our **NGINX Ingress Controllers**.
2. **The Problem:** The physical router (TP-Link ER605) lacked strict internal BGP routing capabilities and fundamentally dropped all cross-subnet routing trying to connect `192.168.0.x` client requests down to the `192.168.1.x` virtual IPs, breaking standard accessibility.
3. **The Solution:** We successfully bypassed the router hardware limitation by introducing a Tier-1 reverse proxy (**NGINX Proxy Manager**) on the local Developer LAN. We bypassed MetalLB completely, mapped local URLs (like `argocd.local`) directly to the physical Control Plane node IPs (`192.168.1.107`), and targeted the automatically generated **NodePorts** (e.g. `32259`) of the NGINX Ingress Controller.

### 🔒 TLS Certificates (cert-manager)
To secure all internal routing, **cert-manager** was deployed as a native Kubernetes add-on. A global `ClusterIssuer` autonomously provisions Self-Signed TLS certificates for internal domains (e.g., `argocd.local`) locking down the Ingress controllers. Because the API traffic is inherently encrypted by Kubernetes, the NGINX Proxy Manager is explicitly configured to use strict `HTTPS` schemes, bridging the self-signed certificates from the internal Ingress Controller out securely to the physical developer network.

---

## 📚 Learning Modules

### 1. Infrastructure Automation (Terraform)
- **Location**: `iac-tools/terraform`
- **Purpose**: Automates the provisioning of the 6 Debian 12 VMs on Proxmox VE.
- **Key Features**: Provisions from a Cloud-Init template, binds static IPs, and mathematically injects AdGuard DNS.

### 2. Configuration Management (Ansible)
- **Location**: `iac-tools/ansible`
- **Purpose**: A sequence of 5 precise playbooks that completely bootstrap the environments.
- **Key Features**:
  - `01-os-prereqs.yml`: OS-level hardening and kernel module injections.
  - `02-bootstrap-clusters.yml`: Highly dynamic `kubeadm init` and automated worker joins.
  - `03-longhorn-storage.yml`: StorageClass configurations with skip-logic safely built-in.
  - `04-ingress-metallb.yml`: Cluster routing.
  - `05-argocd-hub.yml`: GitOps Control Plane setup.

---

## 🚀 Getting Started

### Quick Start

**1. Provision Infrastructure**:
```bash
cd iac-tools/terraform
terraform init
terraform apply
```

**2. Execute Ansible Sequence**:
Navigate to the Ansible directory and execute the playbooks sequentially on a fresh environment:
```bash
cd ../ansible
ansible-playbook -i inventory.ini 01-os-prereqs.yml
ansible-playbook -i inventory.ini 02-bootstrap-clusters.yml
# ... Follow the strict numbering up to 05-argocd-hub.yml
```

**3. Access ArgoCD Locally**:
Because the environment lies behind a secure firewall, we use Kubernetes native port-forwarding to complete GitOps bindings:
```bash
KUBECONFIG=~/.kube/central-hub-config kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --username admin --insecure
```

---

## 📂 Repository Structure

```text
kubernetes-journey/
├── iac-tools/
│   ├── terraform/      # Proxmox VM provisioning
│   └── ansible/        # Cluster setup playbooks
└── project-information/  # Tracked state and internal guides
```

## 📝 Documentation
- **Ansible Sequence**: `iac-tools/ansible/setup-guide.md`
- **Terraform Instructions**: `iac-tools/terraform/setup-guide.md`