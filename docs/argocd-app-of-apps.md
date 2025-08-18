# ArgoCD & The App-of-Apps Pattern

This guide explains how ArgoCD is used in this project and how you can structure a GitOps setup with the **App-of-Apps** pattern to manage many components cleanly.

---

## 1. What Is ArgoCD?

ArgoCD is a GitOps controller that:

-   Watches Git repositories for Kubernetes manifests (plain YAML, Kustomize, Helm, Jsonnet, plugins)
-   Continuously compares desired state (Git) vs live state (cluster)
-   Applies changes automatically (if automated sync enabled) and heals drift

You interact through:

-   Web UI (`http://argocd.localtest.me` in this project)
-   CLI (`argocd`) — optional locally
-   Kubernetes API (`Application` CRD instances in the `argocd` namespace)

---

## 2. Key Concepts Recap

| Term            | Meaning                                                           |
| --------------- | ----------------------------------------------------------------- |
| Application CRD | Tells ArgoCD what repo/path/revision to sync & where to deploy it |
| Project         | Logical grouping & policy boundary for Applications               |
| Sync            | Process of applying Git state to cluster                          |
| Drift           | Difference between actual cluster objects and desired Git state   |
| Automated Sync  | ArgoCD applies + prunes without manual approval                   |
| Self-Heal       | ArgoCD reverts out-of-band changes back to Git state              |
| Prune           | Deletes resources removed from Git                                |

---

## 3. Example Application (Nyancat)

From `configs/apps/manifests/nyancat-argo-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
    name: nyan-cat
    namespace: argocd
spec:
    destination:
        namespace: nyan-cat
        server: https://kubernetes.default.svc
    project: default
    source:
        repoURL: https://github.com/rogerwesterbo/nyan-cat.git
        targetRevision: HEAD
        path: charts/nyan-cat
        helm:
            values: |
                ingress:
                  enabled: true
                  className: 'nginx'
                  hosts:
                    - host: nyancat.localtest.me
                      paths:
                        - path: /
                          pathType: Prefix
    syncPolicy:
        automated:
            prune: true
            selfHeal: true
        syncOptions:
            - CreateNamespace=true
            - ServerSideApply=true
```

Highlights:

-   `repoURL + path + targetRevision` tell ArgoCD how to render the chart.
-   `automated.prune + selfHeal` enable full GitOps.
-   `CreateNamespace=true` saves you from manually creating target namespace.
-   `ServerSideApply=true` uses SSA for better field ownership.

---

## 4. The App-of-Apps Pattern

Instead of manually creating 10–30 `Application` resources, you create a **root (or parent) Application** which itself points to a directory (or repo) containing child Application manifests.

Workflow:

1. Root Application synced by ArgoCD
2. Child `Application` YAMLs are applied (just Kubernetes manifests)
3. Each child Application then syncs its own target repo/chart

Benefits:

-   Single source of truth listing all platform components
-   Easy enable/disable via a single commit (add/remove app manifest)
-   Can version platform independently of product repos

Drawbacks / Cautions:

-   Infinite recursion if misconfigured (avoid root adding itself)
-   Large blast radius of a change in root repo (review carefully)
-   ArgoCD UI flattens but ordering dependencies may need hooks / sync waves

---

## 5. Creating a Root (Platform) Application

Directory layout suggestion (`platform/` repo or subfolder):

```
platform/
  apps/
    argocd-ingress.yaml
    kube-prometheus-stack-app.yaml
    falco-app.yaml
    trivy-app.yaml
    vault-app.yaml
    # ... more Application YAMLs
  root/
    platform-root-app.yaml   # The parent Application (points to ../apps)
```

Example parent Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
    name: platform-root
    namespace: argocd
spec:
    project: default
    source:
        repoURL: https://github.com/example/platform.git
        targetRevision: main
        path: platform/apps
        directory:
            recurse: true
    destination:
        server: https://kubernetes.default.svc
        namespace: argocd
    syncPolicy:
        automated:
            prune: true
            selfHeal: true
        syncOptions:
            - CreateNamespace=true
            - ServerSideApply=true
```

Notes:

-   `directory.recurse: true` allows all YAMLs below `platform/apps` to be included.
-   Each YAML under `platform/apps` should be an `Application` CRD.

---

## 6. Organizing Child Application Files

Tips:
| Strategy | Rationale |
|----------|-----------|
| One file per Application | Blame & change clarity |
| Name files `<component>-app.yaml` | Consistent discovery |
| Use `sync-wave` annotations for ordering | Control bootstrap order |
| Inline minimal Helm values overrides | Keep platform overrides visible |

Sync wave annotation example (lower = earlier):

```yaml
metadata:
    annotations:
        argocd.argoproj.io/sync-wave: '0' # CRDs / infra
```

Common ordering guideline:

1. Ingress / Cert-manager / CRDs
2. Storage operators (Ceph, NFS provisioner)
3. Databases (Postgres Operator, Mongo Operator)
4. Security (Vault, Falco, Trivy)
5. Observability (Prometheus stack, OpenCost)
6. Apps / Demos (Nyancat, custom services)

---

## 7. Managing Secrets in GitOps

Options:
| Approach | Tools | Pros | Cons |
|----------|-------|------|------|
| Plain Kubernetes Secrets | (none) | Simple | Unencrypted in Git |
| Sealed Secrets | SealedSecrets CRD | Encrypted at rest in Git | Key recovery considerations |
| SOPS + KMS + ArgoCD plugin | SOPS, age/GPG/KMS | Strong encryption & portability | Plugin config needed |
| Vault + External Secrets Operator | ESO, Vault | Dynamic credentials | More moving parts |

For quick local learning, plain Secrets are fine (non-production). To graduate, experiment with SOPS or Sealed Secrets.

---

## 8. Handling Dependencies

If a child Application requires CRDs from another (e.g., Crossplane before Crossplane claims), use sync waves or split into phase directories (`00-crds/`, `10-operators/`, etc.).

ArgoCD evaluates waves numerically; same wave resources can apply in parallel.

---

## 9. Drift & Troubleshooting

| Symptom                  | Check                                                          |
| ------------------------ | -------------------------------------------------------------- |
| App stuck in Progressing | `kubectl describe application <name> -n argocd` for conditions |
| Health=Degraded          | Inspect pod logs / events of target namespace                  |
| Secret missing           | Did you add it to repo? Was it pruned?                         |
| CRD not found errors     | Ensure CRD-delivering Application is lower sync wave           |
| Permissions issues       | Validate ArgoCD RBAC / Project resource whitelist              |

ArgoCD CLI (optional):

```bash
argocd app list
argocd app get platform-root
argocd app logs <app-name>
```

---

## 10. Migrating from Imperative -> GitOps Here

1. Identify which components you installed via Helm command.
2. Export their manifests (`helm get manifest <release> -n <ns>`).
3. Create Application YAML pointing to the chart instead (preferred) or commit raw rendered manifests.
4. Remove direct Helm release once ArgoCD successfully owns it (avoid double ownership).

---

## 11. When NOT to Use App-of-Apps

| Scenario                            | Reason                                             |
| ----------------------------------- | -------------------------------------------------- |
| Very large scale (hundreds of apps) | Performance; consider ArgoCD ApplicationSets       |
| Dynamic app generation needed       | Use ApplicationSet (Git, cluster, list generators) |
| Multi-tenant isolation              | Separate ArgoCD Projects & repos per tenant        |

---

## 12. Alternatives / Complements

| Tool           | Role                                               |
| -------------- | -------------------------------------------------- |
| FluxCD         | Alternative GitOps engine (pull model)             |
| Helmfile       | Bulk Helm orchestration (imperative)               |
| Kustomize      | Patch & compose YAML pre-ArgoCD                    |
| ApplicationSet | Declarative template to generate many Applications |

---

## 13. Minimal Root App Repo Template

```
platform-repo/
  README.md
  apps/
    00-ingress-nginx-app.yaml
    01-cert-manager-app.yaml
    02-metallb-app.yaml
    10-postgres-operator-app.yaml
    20-observability-kube-prometheus-app.yaml
    50-demo-nyancat-app.yaml
  root/
    platform-root-app.yaml
```

---

## 14. Next Experiments

-   Add sync waves & observe ordering in UI.
-   Introduce SOPS-encrypted Secrets & ArgoCD plugin.
-   Convert a Helm-installed component here to the root App-of-Apps repo.
-   Add an ApplicationSet to generate one Application per microservice directory.

---

Happy GitOps building!
