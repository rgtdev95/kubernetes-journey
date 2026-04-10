# 🚀 Kubernetes Journey: From Bare Metal to Production

This repository documents my comprehensive journey of building a self-hosted, multi-cluster Kubernetes ecosystem from the ground up. Starting with raw Proxmox VMs, I've progressed through bare-metal cluster provisioning, complex Ansible automation, and finally deployed a Hub-and-Spoke GitOps pipeline using ArgoCD.

## 🏗️ Project Architecture

This project implements a **three-tier Kubernetes infrastructure** running on 6 dedicated Proxmox VMs. It utilizes a strict `kubeadm` bootstrapper rather than lightweight distributions (like K3s/K0s), providing a true enterprise-grade bare-metal experience.

### 🌐 Network Topology
- **Physical Network Gateway**: `192.168.1.1` (TP-Link ER605)
- **Local DNS**: `192.168.1.108` (AdGuard Home LXC)
- **VM Network & Proxmox**: `192.168.1.x/24` (Proxmox vmbr0)

*(For a comprehensive layout, see the complete [Network Architecture Diagram](./project-information/diagrams/network-architecture.md))*

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
- **GitOps Engine**: ArgoCD v3.3.6 (Managing Argo Workflows via App-of-Apps)

---

## 💾 Storage & Networking Layers

### Longhorn Block Storage
Dynamic storage provisioning is achieved using **Longhorn v1.8.0**, strictly deployed across all clusters via Helm configuration. Because each cluster consists of exactly 2 nodes (1 CP, 1 Worker), Longhorn was deliberately configured with a `persistence.defaultClassReplicaCount=2` to ensure healthy volume replication without endlessly waiting for a non-existent third node.

### The MetalLB / Ingress Routing Challenge
A major hurdle in this architecture was exposing the internal Kubernetes Services out to the physical LAN network. 
1. **MetalLB** is deployed in L2 mode and assigns External Virtual IPs from a dedicated pool (e.g. `192.168.1.110`) to the **NGINX Ingress Controller** in each cluster.
2. **AdGuard DNS** resolves `*.local` service domains directly to the MetalLB VIP. Traffic flows straight from the browser to the NGINX Ingress controller — no intermediate reverse proxy required.
3. **NGINX Ingress** routes based on the `Host:` header to the correct backend service.

### 🔒 TLS Certificates (cert-manager)
To secure all internal routing, **cert-manager** was deployed as a native Kubernetes add-on. A global `ClusterIssuer` autonomously provisions Self-Signed TLS certificates for internal domains (e.g., `argocd.local`). TLS is terminated at the **NGINX Ingress** level — internal pods run HTTP only (`secure: false`), preventing double-TLS handshake failures.

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

### 3. GitOps App-of-Apps & Argo Workflows
- **Location**: `gitops/`
- **Purpose**: Implements the "Argo-managing-Argo" pattern. 
- **Key Features**: Uses an ArgoCD `root-app.yaml` to dynamically scan the `gitops/apps/` directory and auto-deploy new infrastructure like **Argo Workflows** without manual `kubectl` intervention.

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

**3. Initialize GitOps Root Application**:
Once ArgoCD is running natively through the Ansible playbook, bootstrap your repository state by strictly applying the root application config:
```bash
kubectl apply -f gitops/root-app.yaml
```

**4. Access UIs Locally**:
Because the environment uses AdGuard DNS for `.local` domain resolution, ensure your machine uses AdGuard (`192.168.1.108`) as its DNS server.
- ArgoCD: `https://argocd.local`
- Argo Workflows: `https://argo-workflows.local`

---

## 📂 Repository Structure

```text
kubernetes-journey/
├── gitops/               # The GitOps engine state (Root App of Apps)
│   ├── root-app.yaml
│   └── apps/             # Child applications (e.g. Argo Workflows)
├── iac-tools/
│   ├── terraform/        # Proxmox VM provisioning
│   └── ansible/          # Cluster setup playbooks
└── project-information/  # Tracked state, diagrams, and internal guides
```

## 📝 Documentation
- **Network Architecture & Diagrams**: `project-information/diagrams/network-architecture.md`
- **Ansible Sequence**: `iac-tools/ansible/setup-guide.md`
- **Terraform Instructions**: `iac-tools/terraform/setup-guide.md`