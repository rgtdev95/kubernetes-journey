# Multi-Cluster Ansible Setup Guide

This directory contains the sequential Ansible playbooks used to provision and bootstrap the entire Kubernetes infrastructure on the Debian 12 Proxmox VMs.

### Prerequisites (WSL/Ubuntu)
1. Ensure Ansible is installed:
   ```bash
   sudo apt update
   sudo apt install -y ansible
   ansible --version
   ```
2. Verify connectivity to all 6 nodes:
   ```bash
   ansible all -i inventory.ini -m ping
   ```

---

## Playbook Execution Sequence

These playbooks must be executed precisely in this numeric order on a fresh environment.

### 1. OS Prerequisites
Prepares exactly 6 VMs (disables swap, configures containerd, standardizes `crictl`, loads kernel modules).
```bash
ansible-playbook -i inventory.ini 01-os-prereqs.yml
```

### 2. Kubernetes Bootstrapping
Initializes `kubeadm` on the 3 control planes, securely joins the 3 worker nodes to their respective clusters, and deploys the Calico CNI.
```bash
ansible-playbook -i inventory.ini 02-bootstrap-clusters.yml
```
*(Validate all nodes joined: `ansible -i inventory.ini control_planes -m command -a "kubectl get nodes"`)*

### 3. Longhorn Storage Provisioning
Deploys the Longhorn v1.8.0 Helm chart across all 3 clusters. Includes a pre-flight check to strictly skip installation if the `longhorn (default)` StorageClass already exists.
```bash
ansible-playbook -i inventory.ini 03-longhorn-storage.yml
```

### 4. MetalLB & NGINX Ingress
Deploys MetalLB dynamically reading from our cluster-specific IP Address Pools (`110-139`, `140-169`, `170-199`), alongside Cert-Manager (self-signed) and the NGINX Ingress Controllers.
```bash
ansible-playbook -i inventory.ini 04-ingress-metallb.yml
```
*(Outputs the dynamic MetalLB IP assigned to each Ingress at the end of the run).*

### 5. ArgoCD Central Hub GitOps
Deploys ArgoCD exclusively to `central-hub-cp`. Automatically hooks the NGINX Ingress Controller to route `https://argocd.local` with strict TLS passthrough.
```bash
ansible-playbook -i inventory.ini 05-argocd-hub.yml
```
*(Outputs the auto-generated native `admin` ArgoCD password at the end of the run).*

---

## Post-Ansible Requirements

After completing playbook `05-argocd-hub.yml`, the infrastructure relies on native CLI proxying to finalize GitOps connectivity. Run the following directly in your WSL terminal to connect the remote environments to the Central Hub:

```bash
# 1. Open the secure API tunnel into Central Hub
KUBECONFIG=~/.kube/central-hub-config kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 2. Authenticate locally
argocd login localhost:8080 --username admin --password <your_password> --insecure

# 3. Register clusters
argocd cluster add kubernetes-admin@kubernetes --kubeconfig ~/.kube/prod-cluster-config --name prod-cluster --yes
argocd cluster add kubernetes-admin@kubernetes --kubeconfig ~/.kube/dev-cluster-config --name dev-cluster --yes
```
