# Goal 4: Multi-Cluster Hybrid Cloud — Project Blue-Tunnel

## Objective

Extend the existing home lab (Cluster A) into a **true hybrid cloud** by connecting it to a remote **Cluster B** running on a separate CGNAT network. Cluster A becomes the centralized management hub (Argo Suite + monitoring). Cluster B runs actual workload apps, managed and monitored remotely from Cluster A through a secure WireGuard tunnel.

---

## Architecture Overview

### What Changes From Goals 1–3

- Goals 1–3 used AdGuard + NPM for local access. That stays unchanged.
- Goal 4 **adds** a second cluster on a completely different network (behind CGNAT) and connects both via WireGuard.
- **VPS-1 is removed** — Cluster A is the home lab; it is already directly accessible via NPM + AdGuard. No public IP needed for admin.
- **VPS-2 remains** — Cluster B is behind CGNAT on a remote network with no fixed public IP. VPS-2 is the WireGuard relay hub for Cluster B.

### Revised Network Topology

| Component | Location | Role | Connectivity |
| :--- | :--- | :--- | :--- |
| **Cluster A** | Home Lab (existing) | Hub: ArgoCD, Argo Workflows, Grafana, Prometheus | Direct LAN access via AdGuard + NPM |
| **WG-LXC-A** | Proxmox (home lab) | Ubuntu LXC — WireGuard bastion for Cluster A | Outbound tunnel to VPS-2 |
| **VPS-2** | Public Cloud | WireGuard relay hub + public ingress for Cluster B apps | Static IP; UDP 51820 open |
| **WG-LXC-B** | Cluster B's Proxmox | Ubuntu LXC — WireGuard bastion for Cluster B | Outbound tunnel to VPS-2 |
| **Cluster B** | Remote network (CGNAT) | Workload: Nextcloud, Docmost, Discourse | Managed remotely via ArgoCD over WireGuard |

### Tunnel Flow

```
[Cluster A LAN]
    └── WG-LXC-A (wg0: 10.100.0.1)
            │  outbound WireGuard (UDP 51820)
            ▼
        VPS-2 (wg0: 10.100.0.254) ── public IP, always reachable
            │  outbound WireGuard (UDP 51820)
            ▼
    WG-LXC-B (wg0: 10.100.0.2)
        └── [Cluster B LAN]
```

All management traffic (ArgoCD → Cluster B API), monitoring traffic (Prometheus `remote_write`), and app traffic (end-user → VPS-2 → Cluster B apps) flows through this tunnel.

---

## Feasibility Assessment

### ✅ WireGuard in Proxmox LXC — DOABLE
This is a well-established pattern. Key requirements:
- WireGuard kernel module must be loaded on the **Proxmox host** (LXC shares host kernel)
- The LXC container config needs TUN/TAP device access:
  ```
  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net dev/net none bind,create=dir
  ```
- Use an **unprivileged** Ubuntu 24.04 LXC (Proxmox community helper script)
- IP forwarding must be enabled inside the LXC: `net.ipv4.ip_forward=1`

### ✅ VPS-2 as WireGuard Relay Hub — DOABLE
- VPS-2 acts as a star-topology hub: both WG-LXC-A and WG-LXC-B peer to it
- Both sides initiate outbound connections (bypasses CGNAT on both ends)
- VPS-2 needs minimal spec: 1 vCPU, 512MB RAM is enough (e.g., Hetzner CAX11 ~€4/mo)
- Forwards port 80/443 via `iptables DNAT` through the WireGuard interface to Cluster B

### ✅ ArgoCD Managing Cluster B Remotely — DOABLE
- ArgoCD (on Cluster A) connects to Cluster B's API server using its WireGuard tunnel IP
- `argocd cluster add` uses a kubeconfig pointing to WireGuard IP (e.g., `10.100.0.2:6443`)
- Cluster B API server must bind on `0.0.0.0` AND include the WireGuard IP in `apiserver-cert-extra-sans` during kubeadm init

### ✅ Prometheus `remote_write` Over WireGuard — DOABLE
- Cluster B runs Prometheus in **Agent Mode** (lightweight, scrape-only, no UI)
- Prometheus Agent sends metrics via `remote_write` to Cluster A's Prometheus endpoint through the WireGuard tunnel
- Grafana on Cluster A queries it all centrally

### ⚠️ Pod CIDR Conflict — MUST FIX
**Critical:** All current clusters use `10.244.0.0/16`. Cluster B MUST use a different CIDR or routing will break across the tunnel.

| Cluster | Pod CIDR | Status |
|---|---|---|
| central-hub | `10.244.0.0/16` | Existing — cannot change |
| prod-cluster | `10.244.0.0/16` | Existing — cannot change |
| dev-cluster | `10.244.0.0/16` | Existing — cannot change |
| **Cluster B** | **`10.245.0.0/16`** | **New — must use this** |

### ⚠️ MTU Tuning — REQUIRED
WireGuard adds a 60-byte header overhead. Without MTU tuning, large packets fragment and cause intermittent failures:

| Interface | MTU Setting |
|---|---|
| WireGuard (`wg0`) | `1420` |
| Calico CNI on Cluster B | `1380` (add `--mtu 1380` in Calico config) |

---

## WireGuard IP Plan

| Node | WireGuard IP | Role |
|---|---|---|
| VPS-2 | `10.100.0.254/24` | Hub (server) |
| WG-LXC-A | `10.100.0.1/24` | Cluster A peer |
| WG-LXC-B | `10.100.0.2/24` | Cluster B peer |

---

## Software Stack

### Cluster A (Hub — existing `central-hub`)
- **ArgoCD v3.3.6** — manages both Cluster A and Cluster B via App-of-Apps
- **Argo Workflows** — CI/CD pipelines
- **Prometheus** — central aggregation (receives `remote_write` from Cluster B)
- **Grafana** — unified dashboard across both clusters

### Cluster B (Remote Workload)
- **Kubernetes** via `kubeadm` (same pattern as existing clusters)
- **Calico CNI** (`10.245.0.0/16`)
- **Longhorn** (if Cluster B has 2 nodes; else use local-path for single-node)
- **MetalLB** — assigns internal LB IPs for app services
- **NGINX Ingress** — receives traffic forwarded from VPS-2
- **Prometheus Agent Mode** — scrapes Cluster B, `remote_write` to Cluster A
- **Applications** — Nextcloud, Docmost, Discourse (deployed via ArgoCD GitOps)

---

## Deployment Phases

### Phase 1: Proxmox Setup — WireGuard LXC on Cluster A
1. Deploy Ubuntu 24.04 LXC on Cluster A's Proxmox via helper script
2. Configure LXC container conf for WireGuard TUN access
3. Install WireGuard inside LXC
4. Enable IP forwarding + NAT rules inside LXC
5. Add AdGuard DNS entry for WG-LXC-A

### Phase 2: VPS-2 Setup
1. Provision VPS-2 (Ubuntu 24.04, static IP)
2. Install WireGuard — configure as hub (listens on UDP 51820)
3. Add WG-LXC-A as the first peer
4. Set up `iptables` DNAT rules for port 80/443 forwarding to Cluster B
5. Enable IP forwarding

### Phase 3: Cluster B Provisioning
1. Provision VMs using same Terraform + Ansible pattern as existing clusters
2. Run `01-os-prereqs.yml` → `02-bootstrap-clusters.yml`
3. **Important:** During `kubeadm init`, include:
   ```
   --pod-network-cidr=10.245.0.0/16
   --apiserver-cert-extra-sans=10.100.0.2
   ```
4. Deploy Calico (with MTU 1380)
5. Deploy MetalLB + NGINX Ingress
6. Deploy cert-manager + ClusterIssuer

### Phase 4: WireGuard LXC on Cluster B + Tunnel Activation
1. Deploy Ubuntu 24.04 LXC on Cluster B's Proxmox
2. Configure LXC for WireGuard TUN access (same as Phase 1)
3. Add WG-LXC-B as a peer on VPS-2
4. Activate the full tunnel: WG-LXC-A ↔ VPS-2 ↔ WG-LXC-B
5. Test: ping `10.100.0.2` from WG-LXC-A

### Phase 5: Cross-Cluster Management (ArgoCD)
1. Extract Cluster B kubeconfig
2. Replace `server:` address with `https://10.100.0.2:6443` (WireGuard IP)
3. Register Cluster B into ArgoCD:
   ```bash
   argocd cluster add cluster-b --name workload-b
   ```
4. Create `gitops/apps/cluster-b/` application manifests targeting `workload-b` as destination

### Phase 6: Monitoring Bridge (Prometheus + Grafana)
1. Deploy Prometheus in **Agent Mode** on Cluster B via GitOps
2. Configure `remote_write` to Cluster A's Prometheus through WireGuard:
   ```yaml
   remote_write:
     - url: "http://10.100.0.1:9090/api/v1/write"
   ```
3. Import Cluster B dashboards into Grafana on Cluster A

---

## Key Risks & Mitigations

| Risk | Mitigation |
|---|---|
| WireGuard LXC requires kernel module on host | Verify `modprobe wireguard` succeeds on both Proxmox hosts before provisioning LXC |
| Pod CIDR overlap breaks cross-cluster routing | Cluster B **must** use `10.245.0.0/16` — enforce in kubeadm init |
| MTU issues cause silent packet drops | Tune WireGuard MTU=1420, Calico MTU=1380 on Cluster B from day 1 |
| CGNAT drops idle WireGuard sessions | Set `PersistentKeepalive = 25` on both WG-LXC-A and WG-LXC-B |
| ArgoCD can't reach Cluster B API | Ensure `--apiserver-cert-extra-sans=10.100.0.2` on Cluster B kubeadm init |