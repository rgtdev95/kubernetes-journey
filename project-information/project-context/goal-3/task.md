# Goal 3: Deploying Argo Rollouts and Argo Events

This checklist tracks the deployment of the remaining Argo Suite components across the infrastructure using the App-of-Apps GitOps pattern.

## Execution Checklist

- [x] Create `gitops/apps/argo-rollouts` directory
- [x] Create `application.yaml` for Argo Rollouts (Chart `2.40.9`, Dashboard enabled)
- [x] Create `ingress.yaml` for Argo Rollouts (Routing `argo-rollouts.local`)
- [x] Update AdGuard custom rules to resolve `argo-rollouts.local` to MetalLB VIP
- [x] Create `gitops/apps/argo-events` directory
- [x] Create `application.yaml` for Argo Events (Chart `2.4.21`)
- [ ] Push to Git and wait for ArgoCD auto-sync
- [ ] Verify applications are Healthy and Synced via `kubectl get applications -n argocd`
- [ ] Verify Argo Rollouts Dashboard via `https://argo-rollouts.local`
