# Complete Multi-Cluster Network Architecture

This document is the single source of truth for all networking across the home lab infrastructure.

---

## Physical Network

| Component | Subnet | IP Address | Role |
|---|---|---|---|
| TP-Link ER605 Router | 192.168.1.x | 192.168.1.1 | Default Gateway |
| Windows PC (Developer) | 192.168.1.x | DHCP / Static | Workstation / WSL |
| AdGuard DNS (LXC) | 192.168.1.x | 192.168.1.109 | DNS Resolver |
| NGINX Proxy Manager | 192.168.1.x | TBD | Tier-1 Reverse Proxy |
| Proxmox VE 9 Host | 192.168.1.x | 192.168.1.100 (Bridge: vmbr0) | Hypervisor |

---

## VM Node IPs (Static - Terraform Provisioned)

| Node | Cluster | Role | IP Address |
|---|---|---|---|
| central-hub-cp | central-hub | Control Plane | 192.168.1.107 |
| central-hub-worker | central-hub | Worker | 192.168.1.102 |
| prod-cluster-cp | prod-cluster | Control Plane | 192.168.1.103 |
| prod-cluster-worker | prod-cluster | Worker | 192.168.1.104 |
| dev-cluster-cp | dev-cluster | Control Plane | 192.168.1.105 |
| dev-cluster-worker | dev-cluster | Worker | 192.168.1.106 |

**Reserved Range:** 192.168.1.100 - 192.168.1.109 (VM Static IPs)

---

## Kubernetes Internal Networks

### Pod Network (Calico CNI)
| Parameter | Value |
|---|---|
| Pod CIDR | 10.244.0.0/16 |
| CNI Plugin | Calico (Tigera Operator) |
| IPAM | Calico Block Affinity |

### Service Network (kube-proxy)
| Parameter | Value |
|---|---|
| Service CIDR | 10.96.0.0/12 (default) |
| Service Range | 10.96.0.1 - 10.111.255.254 |
| DNS (CoreDNS) | 10.96.0.10 |

---

## MetalLB L2 Address Pools

| Cluster | Pool Name | IP Range | Total IPs |
|---|---|---|---|
| central-hub | default-pool | 192.168.1.110 - 192.168.1.139 | 30 |
| prod-cluster | default-pool | 192.168.1.140 - 192.168.1.169 | 30 |
| dev-cluster | default-pool | 192.168.1.170 - 192.168.1.199 | 30 |

> Note: While MetalLB L2 virtual IPs are now on the same `192.168.1.x` subnet as the router and nodes, we still utilize NPM + NodePorts for centralized Domain/TLS proxying.

---

## NGINX Ingress Controller (Per Cluster)

| Cluster | ClusterIP | MetalLB External IP | HTTP NodePort | HTTPS NodePort |
|---|---|---|---|---|
| central-hub | 10.111.249.26 | 192.168.1.110 | 31190 | 32259 |
| prod-cluster | 10.104.184.73 | 192.168.1.140 | 32498 | 30739 |
| dev-cluster | 10.103.153.116 | 192.168.1.170 | 30277 | 30629 |

---

## Cert-Manager

| Parameter | Value |
|---|---|
| Namespace | cert-manager |
| ClusterIssuer Name | selfsigned-issuer |
| Issuer Type | SelfSigned |
| TLS Secret (ArgoCD) | argocd-tls-certificate |

---

## ArgoCD (Central Hub Only)

| Parameter | Value |
|---|---|
| Namespace | argocd |
| Version | v3.3.6 |
| Ingress Host | argocd.local |
| Backend Protocol | HTTPS (port 443) |
| Admin Username | admin |
| Admin Password | lw6QFkNi9IbEdXAK |

---

## NPM Reverse Proxy Mappings

| Domain | NPM Target (Physical IP:NodePort) | Cluster |
|---|---|---|
| argocd.local | https://192.168.1.107:32259 | central-hub |
| prod.local | https://192.168.1.103:30739 | prod-cluster |
| dev.local | https://192.168.1.105:30629 | dev-cluster |

---

## DNS Rewrites (AdGuard)

| Domain | Answer IP | Purpose |
|---|---|---|
| central-hub-cp.local | 192.168.1.107 | VM Node |
| central-hub-worker.local | 192.168.1.102 | VM Node |
| prod-cluster-cp.local | 192.168.1.103 | VM Node |
| prod-cluster-worker.local | 192.168.1.104 | VM Node |
| dev-cluster-cp.local | 192.168.1.105 | VM Node |
| dev-cluster-worker.local | 192.168.1.106 | VM Node |
| argocd.local | NPM IP (TBD) | ArgoCD UI |

---

## Traffic Flow Diagram

```mermaid
flowchart TD
    %% Physical Layer
    Modem(("🌐 Internet Modem"))
    Router{{"🛡️ TP-Link ER605 Router<br>(Gateway: 192.168.1.1)"}}
    
    Modem ==> |"WAN"| Router

    %% Setup
    subgraph PhysicalServer ["🖥️ Physical Server Layer"]
        Proxmox["Proxmox VE Server<br>IP: 192.168.1.100 (1 NIC)<br>Bridge: vmbr0<br>OS: Debian 12"]
    end

    Router ==> |"LAN"| Proxmox

    subgraph KubernetesEnvironment ["☸️ Kubernetes Infrastructure (3 Clusters / 6 VMs)"]
        direction TB

        subgraph GlobalNet ["K8s Internal Networking Options (Applies per cluster)"]
            direction LR
            PodNet["📦 Pod Networking (Calico CNI)<br>CIDR: 10.244.0.0/16<br>Allocates IP addresses to individual Containers/Pods"]
            ClusterIP["🔌 Service / Cluster IP (kube-proxy)<br>CIDR: 10.96.0.0/12<br>Internal Load Balancing & Discovery for Services"]
        end

        subgraph Cluster1 ["1️⃣ Central Hub Cluster (ArgoCD)"]
            direction TB
            Node1_CP["VM 1: central-hub-cp (192.168.1.107)"]
            Node1_W["VM 2: central-hub-worker (192.168.1.102)"]
            MLB1["MetalLB Load Balancer IP Range<br>192.168.1.110 - 139"]
            Ingress1["NGINX Ingress Gateway<br>HTTPS NodePort: 32259"]
            Node1_CP & Node1_W --- MLB1 --- Ingress1
        end

        subgraph Cluster2 ["2️⃣ Production Cluster"]
            direction TB
            Node2_CP["VM 3: prod-cluster-cp (192.168.1.103)"]
            Node2_W["VM 4: prod-cluster-worker (192.168.1.104)"]
            MLB2["MetalLB Load Balancer IP Range<br>192.168.1.140 - 169"]
            Ingress2["NGINX Ingress Gateway<br>HTTPS NodePort: 30739"]
            Node2_CP & Node2_W --- MLB2 --- Ingress2
        end

        subgraph Cluster3 ["3️⃣ Development Cluster"]
            direction TB
            Node3_CP["VM 5: dev-cluster-cp (192.168.1.105)"]
            Node3_W["VM 6: dev-cluster-worker (192.168.1.106)"]
            MLB3["MetalLB Load Balancer IP Range<br>192.168.1.170 - 199"]
            Ingress3["NGINX Ingress Gateway<br>HTTPS NodePort: 30629"]
            Node3_CP & Node3_W --- MLB3 --- Ingress3
        end
    end

    Proxmox -.-> |"Hosts"| Cluster1
    Proxmox -.-> |"Hosts"| Cluster2
    Proxmox -.-> |"Hosts"| Cluster3

    %% Note for Reverse Proxy & AdGuard
    NPM("NGINX Proxy Manager<br>(192.168.1.x Subnet)")
    AdGuard("AdGuard DNS<br>(192.168.1.109)")
    
    Router -.-> AdGuard
    Router -.-> NPM
    NPM -.-> |"Proxies traffic to"| Ingress1
    NPM -.-> |"Proxies traffic to"| Ingress2
    NPM -.-> |"Proxies traffic to"| Ingress3

    %% Styling
    style GlobalNet fill:#f4f6f6,stroke:#7f8c8d,stroke-dasharray: 5 5
    style Cluster1 fill:#eaf2f8,stroke:#3498db
    style Cluster2 fill:#fef9e7,stroke:#f1c40f
    style Cluster3 fill:#f4ecf7,stroke:#9b59b6
    style Proxmox fill:#f39c12,stroke:#e67e22,color:#fff
    style Router fill:#e74c3c,stroke:#c0392b,color:#fff
```
