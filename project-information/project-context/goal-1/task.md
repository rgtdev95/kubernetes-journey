# Every completion of each stage - marked it as complete

# Project Stages & Execution Plan

## [COMPLETED] Stage 1: Infrastructure Provisioning (Terraform)
- **Goal:** Provision 6 VMs on Proxmox VE 9.
- **State:** Local state file (`terraform.tfstate`).
- **VM Specs:** 2 CPU, 4GB RAM (or higher for central-hub), 20GB Disk over Debian 12.
- **IP Assignment:** Assign static IP addresses for each VM corresponding to the IP allocation plan.
- **Network:** Attach to `vmbr0` bridge.

## [COMPLETED] Stage 1.5: DNS Infrastructure (AdGuard LXC)
- **Goal:** Provide a local DNS resolver so your clusters and ArgoCD can route to each other by name.
- **Action:** Run the Proxmox Helper Script in your Proxmox Host Shell: 
  `bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/adguard.sh)"`
- **DNS Records to Add (in AdGuard UI):** 
  - All 6 VM nodes (e.g., `central-hub-cp.local -> 192.168.1.107`, `prod-cluster-cp.local -> 192.168.1.103`)
  - Any future Ingress domains (e.g., `argocd.local -> <metallb-ip>`)
- **DNS Assignment:** Once AdGuard has an IP, we will update the `main.tf` Terraform code with `dns { servers = ["<adguard-ip>"] }` or configure it via Ansible so all VMs use it.

## [COMPLETED] Stage 2: OS Configuration & Prerequisites (Ansible)
- **Goal:** Prepare the Debian 12 nodes for Kubernetes.
- **Inventory:** Located in `iac-tools/ansible/inventory.ini`. All 6 nodes should be referenced.
- **Tasks:**
  - Update system packages.
  - Disable swap (kubeadm requirement).
  - Enable IP forwarding and required kernel modules (`br_netfilter`, `overlay`).
  - Install Container Runtime (`containerd`).
  - Install Longhorn prerequisites (`open-iscsi`, `nfs-common`).
  - Install `kubeadm`, `kubelet`, and `kubectl` (Pinned Version: **v1.34**).

## [COMPLETED] Stage 3: Kubernetes Bootstrap (Ansible / shell)
- **Goal:** Initialize the 3 distinct standard Kubernetes clusters.
- **central-hub cluster:**
  - Init control plane via `kubeadm init --pod-network-cidr=10.244.0.0/16`.
  - Join worker node.
- **prod-cluster:**
  - Init control plane via `kubeadm init --pod-network-cidr=10.244.0.0/16`.
  - Join worker node.
- **dev-cluster:**
  - Init control plane via `kubeadm init --pod-network-cidr=10.244.0.0/16`.
  - Join worker node.
- **Post-Init:** Fetch `admin.conf` (kubeconfig) for all three clusters to local machine for management.

## [COMPLETED] Stage 4: Core Infrastructure Add-ons
- **Goal:** Base cluster networking and storage on all 3 clusters.
- **CNI:** [COMPLETED] Calico deployed with `10.244.0.0/16` CIDR on all 3 clusters.
- **Storage:** [COMPLETED] Longhorn Block Storage deployed natively across all clusters providing dynamic PVC capabilities.
  
## [COMPLETED] Stage 5: MetalLB & Ingress Controllers
- **Goal:** Provide external accessibility.
- **MetalLB:** Deploy to all 3 clusters and configure IPAddressPools (unique per cluster according to allocation plan) and L2Advertisements.
- **Ingress:** Deploy NGINX Ingress Controller.
- **Cert-Manager:** Deploy cert-manager and create a self-signed `ClusterIssuer`.

## [COMPLETED] Stage 5.5: AdGuard DNS → MetalLB VIP
- **Goal:** Route `*.local` service domains to the correct NGINX Ingress without an intermediate reverse proxy.
- **Solution:** AdGuard DNS rewrites resolve service domains (e.g. `argocd.local`, `argo-workflows.local`) directly to the MetalLB External IP (`192.168.1.110`) of the central-hub NGINX Ingress controller.
- **Flow:** Browser → AdGuard DNS → MetalLB VIP → NGINX Ingress → App pod.

## [COMPLETED] Stage 6: GitOps Control Plane (ArgoCD)
- **Goal:** Install and configure ArgoCD on the central hub.
- **Installation:** Install ArgoCD **v3.3.6** centrally on `central-hub`.
- **Expose:** Configure Ingress for ArgoCD UI.
- **Repositories:** Connect ArgoCD to the single GitHub Mono-Repo.
- **Cluster Registration:** Add `prod-cluster` and `dev-cluster` to `central-hub` ArgoCD using `argocd cluster add`.