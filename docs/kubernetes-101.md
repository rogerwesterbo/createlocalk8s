# Kubernetes 101 (Beginner Friendly)

If you're just starting with Kubernetes, this guide will give you the minimum concepts and commands to feel comfortable using this project.

---

## 🔍 What Is Kubernetes?

A container orchestration platform that keeps your containerized applications running: it schedules them, restarts them if they crash, scales them, and gives them networking & storage.

With this repo you create a local cluster using **kind** (Kubernetes in Docker). That cluster behaves like a “real” cluster for learning purposes.

---

## 🧱 Core Building Blocks

| Concept                        | What It Is                                               | Analogy                              |
| ------------------------------ | -------------------------------------------------------- | ------------------------------------ |
| Cluster                        | The whole system (control planes + workers)              | A data center in miniature           |
| Node                           | A machine (Docker container in kind) that runs workloads | A server                             |
| Pod                            | Smallest deployable unit (1+ tightly-coupled containers) | A running process group              |
| Deployment                     | Desired state manager for replicated Pods                | Supervisor keeping N copies running  |
| Service                        | Stable virtual IP & DNS for a set of Pods                | Internal load balancer               |
| Ingress                        | HTTP/HTTPS routing into Services                         | Reverse proxy + virtual host mapping |
| Namespace                      | Logical grouping / scoping                               | Folder / environment                 |
| ConfigMap                      | Non-secret configuration data                            | Plain config file                    |
| Secret                         | Base64-encoded sensitive values                          | Password vault entry                 |
| CRD (CustomResourceDefinition) | Extends the API with new kinds                           | Plugin system                        |
| Operator / Controller          | Automates higher-level logic around CRDs                 | Robot admin                          |

---

## 🔑 kubeconfig & Context

A kubeconfig file tells `kubectl` how to reach a cluster and with what credentials.

After creating a cluster with this project you get: `clusters/kubeconfig-<name>.config`.

Export it so kubectl talks to that cluster:

```bash
export KUBECONFIG="$(pwd)/clusters/kubeconfig-mycluster.config"
```

Check current context:

```bash
kubectl config current-context
```

List contexts:

```bash
kubectl config get-contexts
```

---

## 🏁 First Commands

```bash
kubectl get nodes          # Machines in the cluster
kubectl get pods -A        # All pods in all namespaces
kubectl get ns             # Namespaces
kubectl get svc -A         # Services
kubectl get ing -A         # Ingresses
```

Describe a resource (detailed info + events):

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Logs from a pod:

```bash
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>  # follow
```

Exec into a pod:

```bash
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

---

## 🌐 Accessing Apps (Ingress vs Port-Forward)

This repo configures an **Ingress Controller** (Nginx) and uses `localtest.me` so hostnames like `http://nyancat.localtest.me` resolve to `127.0.0.1`.

If multiple clusters run, ports may shift—see `clusters/clusterinfo-<name>.txt`.

If an app has no ingress yet, you can still reach it via **port-forward**:

```bash
kubectl port-forward -n <namespace> svc/<service-name> 8080:80
# Open http://localhost:8080
```

---

## 🧬 Deploying Stuff (3 Common Paths)

1. Raw Manifests (YAML): `kubectl apply -f myapp.yaml`
2. Helm Chart (packaged templates): `helm install myapp repo/chart --namespace myns --create-namespace`
3. ArgoCD Application (GitOps): Define an Application CRD and ArgoCD syncs it continuously.

This repo supports both Helm (imperative) and ArgoCD Application installs (declarative / GitOps).

---

## 🧾 Inspecting ArgoCD

List ArgoCD apps:

```bash
kubectl get applications -n argocd
```

(Or open the UI: `http://argocd.localtest.me` — admin password in the cluster info file.)

Get app details:

```bash
kubectl describe application <app-name> -n argocd
```

---

## ⚙️ Custom Resources You'll Encounter

| Component     | Custom Resources (examples) | Purpose             |
| ------------- | --------------------------- | ------------------- |
| ArgoCD        | Application                 | GitOps syncing      |
| CloudNativePG | Cluster                     | Postgres HA cluster |
| Crossplane    | XRDs / Composites           | Infra abstractions  |
| Rook Ceph     | CephCluster, CephBlockPool  | Storage backend     |
| Vault         | (Helm-managed statefulset)  | Secrets management  |

List CRDs:

```bash
kubectl get crds | head
```

Inspect a CRD:

```bash
kubectl explain application.spec --recursive | less
```

---

## 🔄 Declarative vs Imperative

| Style       | Example                            | Tradeoff                     |
| ----------- | ---------------------------------- | ---------------------------- |
| Imperative  | `kubectl run nginx --image=nginx`  | Quick, not recorded in git   |
| Declarative | `kubectl apply -f deployment.yaml` | Repeatable, versionable      |
| GitOps      | ArgoCD tracks repo                 | Auditable + drift correction |

Prefer declarative or GitOps for anything long-lived.

---

## 🧹 Cleaning Up

Delete an app you installed with Helm:

```bash
helm uninstall myrelease -n mynamespace
```

Delete arbitrary manifests:

```bash
kubectl delete -f myapp.yaml
```

Delete the whole cluster (from repo root):

```bash
./create-cluster.sh delete mycluster
```

---

## 🧪 Safe Experiments

| Goal               | Try This                                                          |
| ------------------ | ----------------------------------------------------------------- |
| Scale a deployment | `kubectl scale deploy/<name> -n <ns> --replicas=5`                |
| Simulate pod crash | `kubectl delete pod <pod-name> -n <ns>` (controller recreates it) |
| See events         | `kubectl get events -A --sort-by=.lastTimestamp`                  |
| Watch changes      | `kubectl get pods -n <ns> -w`                                     |

---

## ❓ When Stuck

1. Check pod status: `kubectl get pods -n <ns>`
2. Describe the pod: `kubectl describe pod <pod> -n <ns>`
3. View logs: `kubectl logs <pod> -n <ns>`
4. Events: `kubectl get events -n <ns> --sort-by=.lastTimestamp | tail`
5. Look at ArgoCD app status if GitOps managed.

---

## 📚 Next Steps

-   Learn YAML basics (apiVersion, kind, metadata, spec)
-   Explore official docs: https://kubernetes.io/docs/home/
-   Try writing a simple Deployment + Service by hand
-   Move to GitOps (ArgoCD) once comfortable

---

Happy learning! Reach back to the main README when you're ready for the full feature set.
