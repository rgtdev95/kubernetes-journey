# [COMPLETED] Goal 2: Deploying Argo Workflows via GitOps

## Objective
Establish a serverless workflow engine directly onto the `central-hub` cluster by deploying **Argo Workflows**. This deployment must natively utilize the "App-of-Apps" GitOps pattern via ArgoCD in our Mono-Repo architecture.

---

## The Approach (The "App of Apps" Pattern)

Instead of manually deploying the Argo Workflows Helm chart, we utilized ArgoCD's recursive directory scanning capabilities.

1. **The Root Application (`root-app.yaml`):**
   This is the literal "Brain" of the repository. We applied this file *one time only* to the cluster natively via `kubectl apply -f root-app.yaml`. 
   It was strictly configured with `recurse: true` so that it autonomously scans the `gitops/apps/` Git folder structure for any child applications.

2. **The Child Application (`argo-workflows/application.yaml`):**
   This manifest actively instructs ArgoCD to fetch the official Helm Chart straight from `https://argoproj.github.io/argo-helm`. Because we committed this file to the folder that the Root App was watching, ArgoCD spontaneously discovered it and magically deployed Argo Workflows without us ever needing to run `helm` manually!

### Why App-of-Apps over Manual Configuration?
While Argo Workflows could have been manually provisioned via the ArgoCD UI, utilizing the `root-app` pattern creates true Enterprise GitOps:

* **Disaster Recovery:** If the entire `central-hub` cluster physically burns down, we do not lose any UI-configured settings. We simply rebuild the empty VMs, execute `kubectl apply -f root-app.yaml` exactly once, and ArgoCD will autonomously scan our GitHub repository and rebuild every single application back to its precise previous state.
* **Autonomous Scaling:** When we expand to deploying 40 distinct microservices (Grafana, backend APIs, etc.), we do not need to click through the ArgoCD UI 40 times. We simply drop 40 YAML declarations into our local `gitops/apps/` folder, Git push, and the `root-app` will instantaneously detect and deploy them across the infrastructure without human intervention.

---

## Execution Steps Taken

1. Extracted our standard `application.yaml` scaling Argo Workflows to natively attach to the `argoworkflows` namespace.
2. Comitted and pushed structure to `main`:
   ```text
   gitops/
   ├── root-app.yaml
   └── apps/
       └── argo-workflows/
           ├── application.yaml
           └── ingress.yaml
   ```
3. Authorized our public GitHub Repository natively in the ArgoCD Settings UI.
4. Performed the one-time manual bootstrap of the Root Application (`kubectl apply -f gitops/root-app.yaml`).
5. Successfully connected to `https://argo-workflows.local` using NGINX.

---

## 🛑 Troubleshooting Notes (The 502 Bad Gateway Issue)

### Issue
When attempting to access the Argo Workflows UI after initial deployment, NGINX repeatedly threw a `502 Bad Gateway` error, effectively locking us out.

### Root Cause
1. Kubernetes automatically terminated our HTTPS via the NGINX Ingress using our `cert-manager` self-signed cluster issuer.
2. However, the internal `argo-workflows-server` pod was *also* blindly trying to encrypt the same stream natively on its own using a generic, mismatched certificate.
3. Because NGINX was strictly forcing `backend-protocol: "HTTPS"`, the internal SSL Handshake brutally failed between the NGINX pod and the Argo Workflows server pod.

### Resolution (TLS Termination Paradigm)
We modified the inner deployment structure strictly enforcing **TLS Termination** at the doorway (NGINX), while keeping the internal house (Argo) fully decoupled:
1. Pushed `secure: false` parameter to the native `application.yaml` Helm values, forcefully degrading the internal Argo Workflows server down to an HTTP-only interface.
2. Purged the `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` annotation out of our `ingress.yaml` file so NGINX stopped desperately demanding an SSL handshake.

Upon Git Push, ArgoCD rapidly ingested the differential and resolved the 502 natively!
