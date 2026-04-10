# Private Infrastructure Notes & Validation Logs

## 📅 April 2026 - MetalLB & AdGuard Direct Access Validated

**Status:** Confirmed fully working on `central-hub`

### The Setup
We completely eliminated the Tier-1 NGINX Proxy Manager (NPM) from the architecture.
Instead of `User -> NPM -> NodePort (32259) -> Ingress`, the traffic now flows identically to a production cloud environment:
`User -> AdGuard DNS -> MetalLB VIP (192.168.1.110) -> NGINX Ingress (443)`

### How it was validated:
1. **AdGuard Rewrite:** Set `argocd.local` and `argo-workflows.local` to point directly to `192.168.1.110` (the MetalLB VIP).
2. **Access Test:** Opening `https://argocd.local` directly in the Windows browser successfully routes into the cluster.
3. **The Ping Illusion:** We discovered that running `ping 192.168.1.110` from the Windows machine will fail and return `Destination host unreachable`. This is expected! The node `kube-proxy` grabs the packet but drops ICMP. However, TCP ports (80/443) connect instantly. 

**Takeaway:** Never trust a failing ping to a Kubernetes LoadBalancer IP. Always test the specific TCP port!

### How Cross-Subnet MetalLB Routing Actually Works (The "Why")
Wait, if ARP (Layer 2) broadcasts can't cross routers, how did your Windows PC on `192.168.0.x` reach MetalLB on `192.168.1.x`? Here is the exact path the packet takes:

1. **The DNS Lookup:** Your browser asks AdGuard (`192.168.1.108`) for `argocd.local`. AdGuard replies: `192.168.1.110`.
2. **The Gateway Hand-off:** Windows realizes `192.168.1.110` is on a different subnet. It does not send an ARP request. Instead, it sends the TCP packet directly to its Default Gateway (the TP-Link router at `192.168.0.1`).
3. **The Router's ARP Request:** The TP-Link router looks at the destination (`192.168.1.110`) and knows it has a direct connection to that network. *The router* sends an ARP request onto the `192.168.1.x` VLAN asking "Who has 192.168.1.110?".
4. **MetalLB Answers:** The MetalLB `speaker` pod running on one of the Kubernetes nodes hears the router's ARP request. It replies to the router with the physical MAC address of the node it resides on.
5. **The Final Delivery:** The TP-Link router sends the web traffic to that node. `kube-proxy` intercepts it at the node's network interface and hands it over to the NGINX Ingress controller pod.

This is why **TCP works but Ping fails**: The router successfully hands the packet to the node, but Kubernetes LoadBalancer `Service` endpoints only expose specific configured ports (80/443). The node receives the ICMP ping packet but has no rule for it, immediately rejecting it and returning `Destination host unreachable` to your Windows PC.
