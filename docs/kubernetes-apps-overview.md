# Kubernetes Apps Overview (What They Are & Why They're Nice Locally)

This repo can install a curated set of platform + demo components using either Helm or ArgoCD Applications. This guide explains what each does, why it’s valuable in a local learning / prototyping environment, and when you might pick it in real projects.

---

## Quick Reference Table

| App / Stack                     | Category              | What It Gives You                              | Nice Locally For                        | Install (Helm Alias) | Install (ArgoCD Alias) |
| ------------------------------- | --------------------- | ---------------------------------------------- | --------------------------------------- | -------------------- | ---------------------- |
| Nginx Ingress Controller        | Networking / Ingress  | HTTP(S) routing + host/path rules              | Testing real ingress + TLS flows        | `ihn`                | `ian`                  |
| ArgoCD                          | GitOps                | Declarative sync from Git to cluster           | Practicing GitOps workflows             | `iha`                | (core bootstrap)       |
| Cert-Manager                    | PKI / TLS             | Auto-issue & renew certs (self-signed / ACME)  | Learning TLS cert issuance pipelines    | —                    | `iacm`                 |
| Metallb                         | Load Balancer         | Provides LoadBalancer IPs in bare-metal / kind | Simulating cloud LB behavior            | `ihm`                | `iam`                  |
| Minio Operator                  | Object Storage (S3)   | S3-compatible buckets                          | Practicing apps needing object storage  | `ihmin`              | `iamin`                |
| NFS Subdir External Provisioner | Storage               | Dynamic ReadWriteMany PVs backed by host NFS   | Shared volume experiments               | `ihnfs`              | `ianfs`                |
| Rook Ceph (Operator)            | Storage Orchestration | Manages Ceph clusters                          | Exploring distributed storage           | `ihrco`              | `iarco`                |
| Rook Ceph (Cluster)             | Storage Backend       | Ceph block / object / filesystem               | Stateful workloads resilience trials    | `ihrcc`              | `iarcc`                |
| MongoDB (Operator)              | Database Operator     | CRDs to declaratively manage MongoDB           | Learning DB operator patterns           | `ihmdb`              | `iamdb`                |
| MongoDB (Instance)              | Database              | Actual MongoDB deployment                      | Testing apps needing Mongo              | `ihmdbi`             | `iamdbi`               |
| CloudNativePG (Operator)        | Database Operator     | Postgres cluster management CRDs               | Studying HA Postgres automation         | `ihpg`               | `iapg` (operator)      |
| CloudNativePG Cluster           | Database              | Multi-instance Postgres cluster                | SQL dev + HA failover demo              | (part of `ihpg`)     | `iapg` (cluster)       |
| PgAdmin4                        | DB GUI                | Web UI for Postgres                            | Inspect schema, run queries             | `ihpa`               | `iapga`                |
| Falco                           | Runtime Security      | Syscall-based threat detection                 | Observing security events               | `ihf`                | `iaf`                  |
| Trivy Operator                  | Security / SBOM       | Image & config vulnerability scanning          | Learning security shift-left            | `iht`                | `iat`                  |
| HashiCorp Vault                 | Secrets Management    | Centralized secrets + encryption               | Practicing secret injection & policies  | `ihv`                | `iav`                  |
| Redis Stack                     | Cache / Data          | Redis + modules (JSON, Search, etc.)           | Caching patterns, pub/sub, JSON docs    | `ihrs`               | `iars`                 |
| Crossplane                      | Infra Abstraction     | Compose infra APIs / claim external services   | Exploring platform engineering patterns | `ihcr`               | `iacr`                 |
| Kube-Prometheus-Stack           | Observability         | Prometheus + Alertmanager + Grafana            | Metrics / dashboards & alerting basics  | —                    | `iap`                  |
| Kubeview                        | Cluster Visualization | UI to explore resources graphically            | Visualizing relationships               | —                    | `iakv`                 |
| OpenCost                        | Cost Analysis         | Estimation of per‑resource cost                | Understanding resource cost attribution | —                    | `iaoc`                 |
| Nyancat App                     | Demo                  | Simple sample workload via ingress             | Smoke testing ingress + ArgoCD          | —                    | `iac`                  |
| Vault (Unseal Automation)       | Bootstrap             | Auto init/unseal & output keys                 | Rapid experimentation                   | (within `ihv`)       | (within `iav`)         |
| NFS + Minio Together            | Pattern               | RWX + Object storage                           | Testing hybrid storage patterns         | (combine above)      | (combine above)        |

---

## Detailed Explanations

### 1. Ingress & Traffic

**Nginx Ingress Controller**

-   Provides Layer 7 routing based on host + path.
-   Allows you to simulate production-style ingress rules with `*.localtest.me` hostnames.
-   Essential for testing how multiple services co-exist under common domains.

**Cert-Manager**

-   Automates certificate issuance (self-signed, ACME/Let’s Encrypt if configured, or custom issuers).
-   Locally: useful to understand Certificate / Issuer CRDs and TLS secret creation.

**Metallb**

-   Implements the "LoadBalancer" Service type in non-cloud environments by assigning IPs from a pool.
-   Lets you experiment with Services of type LoadBalancer exactly like on cloud without external hardware.

### 2. Storage (Block / Shared / Object)

**Minio Operator**

-   S3-compatible object storage. Great for practicing apps that expect AWS S3.
-   Operator version allows more lifecycle control & multi-tenant setups.

**NFS Subdir External Provisioner**

-   Simple dynamic provisioning of RWX (ReadWriteMany) volumes—handy for shared state experiments.
-   Good stepping stone before more complex distributed storage like Ceph.

**Rook Ceph (Operator + Cluster)**

-   Operator deploys and manages Ceph (distributed storage platform) offering block, object, and filesystem interfaces.
-   Allows exploring persistent storage reliability, replication, and dynamic provisioning semantics.
-   More complex; start after grasping simpler provisioners.

### 3. Databases & Data Services

**MongoDB Operator & Instance**

-   Operator introduces CRDs (e.g., MongoDB resource) for declarative cluster spec.
-   Instance deployment demonstrates secret management, readiness, and access via port-forward.

**CloudNativePG (Operator + Cluster)**

-   Modern Postgres operator: manages HA clusters, backups, failover.
-   Teaches reconciliation loops: update spec → operator adjusts actual state.

**PgAdmin4**
**Redis Stack (Server + Modules)**

-   Provides Redis plus enhanced modules (RedisJSON, Search, TimeSeries, Bloom) via the upstream redis-stack-server chart.
-   Excellent for prototyping caching, document storage (JSON), pub/sub messaging, search indexing, and time‑series ingestion in one lightweight component.
-   Port-forward: `kubectl port-forward -n redis svc/redis-stack-server 6379:6379` then `redis-cli -h localhost -p 6379`.

-   Browser-based administration UI for Postgres.
-   Low friction for inspecting DB objects when learning CNPG.

### 4. Security & Compliance

**Falco**

-   Runtime security engine: watches syscalls inside nodes → surfaces suspicious behavior (crypto miners, unexpected shells, etc.).
-   Locally: great for learning detection tuning & generating test events.

**Trivy Operator**

-   Continuous Kubernetes-native scanning (images, misconfigs, SBOM generation).
-   Builds security posture awareness habits during development.

**HashiCorp Vault**

-   Central secret storage, dynamic credentials, encryption as a service.
-   Auto-init/unseal flow here accelerates experimentation with auth backends & policies.

### 5. Platform & Infra Abstraction

**Crossplane**

-   Extends the Kubernetes API to manage external cloud resources using CRDs.
-   Locally: practice composition / claims pattern without touching real cloud (can still point to real providers if creds available).

### 6. Observability & Insights

**Kube-Prometheus-Stack**

-   Bundles Prometheus, Alertmanager, Grafana, node exporters, etc.
-   Local benefit: learn scraping, PromQL, dashboard import, alert rule structures.

**Kubeview**

-   Visual representation of cluster objects; lowers barrier for newcomers to navigate relationships.

**OpenCost**

-   Allocates resource cost across namespaces, pods, workloads.
-   Locally: understand the inputs needed for real cost reporting; pairs with metrics stack.

### 7. Sample / Demo

**Nyancat Application**

-   Lightweight fun app to validate ingress, DNS, ArgoCD sync, and port handling when multiple clusters run.
-   Socially useful as a visible "it works" proof.

### 8. Supporting Patterns

**Vault Unseal Automation**

-   Script captures unseal keys/root token to `vault-init.json` to skip manual ceremony.
-   In production you'd use auto-unseal (KMS/HSM); here we prioritize speed of learning.

**Combined Storage (NFS + Minio + Ceph)**

-   Showcases different storage paradigms: shared POSIX (NFS), object (Minio), distributed robust (Ceph).
-   Helpful to compare access modes & performance tradeoffs conceptually.

---

## Choosing What To Install First

| Learning Goal              | Start With               | Next Steps                            |
| -------------------------- | ------------------------ | ------------------------------------- |
| Basic routing + GitOps     | Nginx + ArgoCD + Nyancat | Add Cert-Manager, Metallb             |
| Storage fundamentals       | NFS or Minio             | Progress to Rook Ceph                 |
| Database operator patterns | CloudNativePG Operator   | Add PgAdmin, then MongoDB Operator    |
| Caching / polyglot storage | Redis Stack              | Add MongoDB / Postgres for comparison |
| Security basics            | Trivy Operator           | Add Falco for runtime events          |
| Observability              | Kube-Prometheus-Stack    | Layer in OpenCost                     |
| Infra abstraction          | Crossplane               | Compose your own XRDs                 |
| Secrets management         | Vault                    | Integrate apps using Vault secrets    |

---

## Common Commands Cheat Sheet

```bash
# List ArgoCD applications
a kubectl get applications -n argocd

# Check ingress resources
kubectl get ing -A

# View PVCs and StorageClasses
kubectl get sc
kubectl get pvc -A

# Watch Falco events (logs)
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# List CRDs added by operators
kubectl get crds | grep -E 'argoproj|vault|postgres|mongodb|crossplane|trivy|falco|redis'
```

---

## Cleanup Considerations

-   Uninstall Helm releases before deleting cluster if you want to observe finalizers & cleanup logic.
-   Some operators (e.g., Crossplane, Rook) create CRDs; deleting the cluster clears them automatically (since kind nodes disappear), but in a persistent cluster you would remove CRDs last.

---

## Production vs Local Differences

| Aspect       | Local (kind)                             | Production                                     |
| ------------ | ---------------------------------------- | ---------------------------------------------- |
| LoadBalancer | Metallb IP pool                          | Cloud LB (ELB / GCLB / etc.)                   |
| Storage      | HostPath / NFS / Ceph-in-Docker          | Cloud block (EBS / PD) + managed object stores |
| TLS          | Often self-signed                        | Public ACME / enterprise PKI                   |
| Secrets      | Plain Kubernetes Secret / Vault dev keys | Encrypted at rest + Vault auto-unseal          |
| Persistence  | Ephemeral (container Fs)                 | Durable volumes, backups                       |

---

## Next Learning Paths

-   Add a simple CI workflow to push manifest changes & watch ArgoCD auto-sync.
-   Write a Crossplane Composition to abstract a hypothetical app environment.
-   Create custom Grafana dashboards and alert rules.
-   Add image signing (Cosign) + verify in admission policies (future enhancement potential).

---

Happy platform building! If something is missing here, open an issue or PR.
