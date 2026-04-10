# 🧠 GEMINI.md — AI Context File for kubernetes-journey

> This file is read automatically by Gemini at the start of every session.
> It gives the AI full awareness of this project without needing re-explanation.
> **Keep this file updated** as the project evolves.

---

## 📌 Project Identity

- **Project Name**: Kubernetes Journey
- **Type**: Self-hosted, bare-metal, multi-cluster Kubernetes ecosystem (Home Lab)
- **Purpose**: Learning & documenting enterprise-grade Kubernetes from the ground up — Proxmox VMs → ArgoCD GitOps → Argo Suite
- **Repository**: GitHub Mono-Repo (`rgtdev95/kubernetes-journey`)

---

## 🏗️ Infrastructure Architecture

### Hypervisor & OS
- **Hypervisor**: Proxmox VE 9
- **OS**: Debian 12 (on all VMs)
- **VM Specs**: 2 vCPU, 4GB RAM, 20GB Disk (per node)

### Cluster Layout (3 Clusters, 6 VMs total)

| Cluster | Role | Control Plane IP | Worker IP |
|---|---|---|---|
| `central-hub` | ArgoCD + Argo Suite Control Plane | `192.168.1.107` | `192.168.1.102` |
| `prod-cluster` | Production Workloads | `192.168.1.103` | `192.168.1.104` |
| `dev-cluster` | Development Workloads | `192.168.1.105` | `192.168.1.106` |

### Network Topology
- **Physical Gateway**: `192.168.1.1` (TP-Link ER605)
- **Local DNS**: `192.168.1.108` (AdGuard Home on LXC) — resolves `*.local` service domains to MetalLB VIPs
- **MetalLB Pools**:
  - `central-hub`: `192.168.1.110–139`
  - `prod-cluster`: `192.168.1.140–169`
  - `dev-cluster`: `192.168.1.170–199`

---

## 🛠️ Core Stack & Versions

| Component | Version | Notes |
|---|---|---|
| Kubernetes | `1.34` via `kubeadm` | No K3s/K0s — pure bare-metal |
| CNI | Calico | Pod CIDR: `10.244.0.0/16` |
| GitOps Engine | **ArgoCD v3.3.6** | Hub-Spoke model on `central-hub` |
| Ingress | NGINX Ingress Controller | NodePort exposed, proxied via NPM |
| TLS | cert-manager (Self-Signed) | `ClusterIssuer` on each cluster |
| Storage | **Longhorn v1.8.0** | `replicaCount=2` (2-node clusters) |
| Load Balancer | MetalLB (L2 mode) | IPs per cluster (see table above) |
| Workflow Engine | **Argo Workflows** | Deployed on `central-hub` |

---

## 🔁 GitOps Strategy: App-of-Apps

The repository uses a **strict App-of-Apps pattern**. The `root-app.yaml` is the single bootstrap:

```
gitops/
├── root-app.yaml          ← Applied once manually: kubectl apply -f
└── apps/
    └── argo-workflows/    ← Auto-discovered by root-app (recurse: true)
        ├── application.yaml
        └── ingress.yaml
```

**Rule**: New services are added by dropping `application.yaml` into `gitops/apps/<service-name>/` and pushing to `main`. ArgoCD auto-detects and deploys. **No manual Helm or kubectl required.**

### TLS Termination Pattern (Important!)
- TLS is **terminated at the NGINX Ingress** level (self-signed cert via cert-manager)
- Internal pods run **HTTP only** (e.g., `secure: false` in Argo Workflows Helm values)
- NGINX Ingress receives traffic at the MetalLB VIP — no intermediate reverse proxy layer

---

## 🧰 IAC Tools

### Terraform (`iac-tools/proxmox-a/`, `iac-tools/proxmox-b/`)
- Provisions Debian 12 VMs from Cloud-Init template
- Injects static IPs + AdGuard DNS (`192.168.1.108`) via cloud-init
- **Local state** (no remote backend)

### Ansible (Run via WSL on Windows)
- Version: `core 2.16.3`
- Playbook sequence (`iac-tools/ansible/`):
  1. `01-os-prereqs.yml` — OS hardening, kernel modules (`open-iscsi`, `nfs-common`)
  2. `02-bootstrap-clusters.yml` — `kubeadm init` + worker join
  3. `03-longhorn-storage.yml` — StorageClass with skip-logic
  4. `04-ingress-metallb.yml` — MetalLB + NGINX Ingress setup
  5. `05-argocd-hub.yml` — ArgoCD install on `central-hub`

---

## 🗺️ Project Goals & Status

| Goal | Description | Status |
|---|---|---|
| **Goal 1** | Build 3 Kubernetes clusters with kubeadm + ArgoCD Hub-Spoke | ✅ COMPLETED |
| **Goal 2** | Deploy Argo Workflows via GitOps App-of-Apps | ✅ COMPLETED |
| **Goal 3** | Deploy Argo Rollouts via GitOps (namespace: `argorollouts`) | 🔵 IN PROGRESS |
| **Goal 3.5** | Deploy Argo Events via GitOps (namespace: `argoevents`) | ⏳ PENDING |
| **Goal 4** | Hybrid Cloud: Connect remote Cluster B (CGNAT) via WireGuard LXC bastions + VPS-2 relay | ⏳ PENDING |

See `project-information/project-context/` for detailed plans per goal.

### Goal 1 — Completed Stages
All 6 stages are done. Execution order for reference:
1. ✅ **Stage 1** — Terraform: Provision 6 Debian 12 VMs on Proxmox VE 9
2. ✅ **Stage 1.5** — AdGuard DNS LXC: DNS records for all 6 nodes + future Ingress domains
3. ✅ **Stage 2** — Ansible `01-os-prereqs.yml`: OS hardening, containerd, kubeadm v1.34 install
4. ✅ **Stage 3** — Ansible `02-bootstrap-clusters.yml`: `kubeadm init` + worker join on all 3 clusters
5. ✅ **Stage 4** — Calico CNI + Longhorn storage deployed on all 3 clusters
6. ✅ **Stage 5** — MetalLB (L2) + NGINX Ingress + cert-manager ClusterIssuer on all 3 clusters
7. ✅ **Stage 5.5** — AdGuard DNS updated: service domains (`argocd.local`, `argo-workflows.local`) point directly to MetalLB VIP `192.168.1.110`
8. ✅ **Stage 6** — ArgoCD v3.3.6 on `central-hub`, prod + dev clusters registered via `argocd cluster add`

### Goal 2 — Key Troubleshooting: 502 Bad Gateway
Root cause: NGINX Ingress forced `backend-protocol: HTTPS` while Argo Workflows server also terminated TLS → double-TLS SSL handshake failure.
Fix: Set `secure: false` in Argo Workflows Helm values + remove `backend-protocol: HTTPS` annotation from `ingress.yaml`.

---

## 🗂️ Repository Structure

```
kubernetes-journey/
├── GEMINI.md                          ← You are here (AI context)
├── README.md                          ← Human-facing documentation
├── .geminiignore                      ← Files hidden from AI
├── gitops/
│   ├── root-app.yaml                  ← One-time bootstrap ArgoCD root app
│   └── apps/
│       └── argo-workflows/            ← Argo Workflows GitOps manifests
├── iac-tools/
│   ├── proxmox-a/                     ← Terraform for Proxmox cluster A
│   └── proxmox-b/                     ← Terraform for Proxmox cluster B
└── project-information/
    ├── diagrams/                      ← Network architecture diagrams
    ├── kubeadm-installation-guide/    ← Step-by-step cluster setup guide
    ├── project-context/               ← Goal tracking (one folder per goal)
    │   ├── goal-1/
    │   │   ├── plan.md                ← Architecture decisions & approach
    │   │   └── task.md                ← Step-by-step checklist with [COMPLETED] markers
    │   ├── goal-2/
    │   │   ├── plan.md
    │   │   └── task.md
    │   ├── goal-3/
    │   │   ├── plan.md
    │   │   └── task.md
    │   └── goal-4/
    │       ├── plan.md                ← Hybrid cloud WireGuard tunnel plan
    │       └── task.md
    └── troubleshooting/               ← Documented issues & resolutions
```

---

## ⚠️ Key Decisions & Gotchas (AI Must Know These)

1. **Longhorn replica=2**: All clusters have only 2 nodes. Longhorn must use `defaultClassReplicaCount=2` or volumes will stay `Pending`.
2. **No double-TLS**: Never configure `backend-protocol: HTTPS` on NGINX Ingress if the backend pod also terminates TLS. This causes 502 errors.
3. **kubeadm only**: Do not suggest K3s, K0s, or managed Kubernetes (EKS/GKE). This is a deliberate bare-metal learning exercise.
4. **DNS is AdGuard**: All `.local` domains resolve via AdGuard at `192.168.1.108`. New services need a DNS entry there.
5. **ArgoCD Hub-Spoke**: `central-hub` is the only cluster with ArgoCD. `prod-cluster` and `dev-cluster` are remote targets registered via `argocd cluster add`.
6. **WSL for Ansible**: Ansible runs in WSL on Windows, not PowerShell. Use Linux-style paths and commands.
7. **Mono-Repo for all clusters**: A single GitHub repo manages all 3 clusters via ArgoCD ApplicationSets or separate Application manifests targeting different cluster destinations.
8. **WireGuard in LXC (Goal 4)**: WireGuard runs in Ubuntu LXC containers on each Proxmox host. The WireGuard kernel module must be loaded on the **Proxmox host** — LXC containers share the host kernel. LXC conf needs `lxc.cgroup2.devices.allow: c 10:200 rwm` and TUN device bind-mount.
9. **Pod CIDR — No Overlap (Goal 4)**: Existing clusters all use `10.244.0.0/16`. Cluster B (remote) **must** use `10.245.0.0/16`. MTU on Cluster B's Calico must be set to `1380` (WireGuard overhead).
10. **CGNAT Keepalive (Goal 4)**: Set `PersistentKeepalive = 25` on all WireGuard peers behind CGNAT to prevent idle tunnel drop.
11. **MetalLB L2 Ping Gotcha**: Pinging a MetalLB VIP from a different subnet (like Windows `192.168.0.x` → K8s `192.168.1.110`) may return "Destination host unreachable" from a worker node. This is normal. MetalLB only responds on the specific Service ports (80/443). Always test with `curl` or a browser, never just `ping`.

---

## 🧠 How to Work With Me Effectively

- **Starting a new goal**: Ask me to update `project-context/goal-N/` with a plan before we start building.
- **Remembering decisions**: Important architectural choices go in this `GEMINI.md` under "Key Decisions".
- **Sensitive data**: Never write IPs, passwords, or tokens inline — always reference `.env` files (which are gitignored).
- **Asking about status**: Check the Goals table above, then read `project-context/goal-N/plan.md` for the approach and `task.md` for the step-by-step checklist.
