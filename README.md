# createlocalk8s

New to Kubernetes? Start here: [docs/kubernetes-101.md](./docs/kubernetes-101.md)

Need more info about ArgoCD (perhaps the most central part except kubernetes?) & App-of-Apps pattern: [docs/argocd-app-of-apps.md](./docs/argocd-app-of-apps.md)

Just need some information about the apps, see here: [docs/kubernetes-apps-overview.md](./docs/kubernetes-apps-overview.md)

Create and experiment with local Kubernetes clusters using [kind](https://kind.sigs.k8s.io/) + Docker, then bootstrap common platform components (ArgoCD, ingress, databases, security, storage, cost / monitoring, etc.) either directly with Helm or via ArgoCD Applications.

> Currently supports macOS & Linux (also works under WSL2). Cygwin/MSYS shells may work but are not officially tested.

---

![Workflow Diagram](./docs/create-cluster.png)

## ✨ Key Features

-   Interactive cluster creation (name, control planes, workers, Kubernetes version)
-   Supported Kubernetes versions (kind node images) baked in: 1.34.x → 1.25.x (see `scripts/variables.sh` for full list)
-   Automatic port mapping adjustment when multiple clusters run simultaneously (avoids 80/443 conflicts)
-   Optional automatic ArgoCD + Nginx Ingress install during cluster creation
-   Post-create helper to install a sample Nyancat app (demo ingress + ArgoCD)
-   Rich subcommands to list, inspect, delete clusters & fetch kubeconfig
-   One-liner Helm installers for: ArgoCD, Crossplane, Rook Ceph (operator/cluster), Falco, Trivy, Vault, Metallb, Minio, NFS provisioner, MongoDB (operator / instance), CloudNativePG (operator / cluster), PgAdmin4, Redis Stack, Nginx Controller
-   Matching ArgoCD Application installers (GitOps style) for the same stack + monitoring (kube-prometheus-stack), OpenCost, Redis Stack, etc.
-   Generates per-cluster info + kubeconfig files under `clusters/`
-   Consistent colored output & spinners, with readiness waits for core components
-   Uses `localtest.me` wildcard DNS (no /etc/hosts changes needed)

---

## 🧱 Repository Layout (selected)

```
create-cluster.sh          # Entry point CLI wrapper
scripts/
	variables.sh             # Global defaults (versions, colors, flags)
	core/
		config.sh              # Help + command routing + logo
		cluster.sh             # Interactive creation / deletion / info
		utils.sh               # Prereq & utility helpers
	installers/
		helm.sh                # Generic + specific Helm installers
		apps.sh                # ArgoCD Application installers & post steps
configs/apps/manifests/    # ArgoCD Application YAMLs & supporting manifests
clusters/                  # Generated: kubeconfig & clusterinfo-* per cluster
docs/                      # Additional documentation & diagram(s)
```

---

## ✅ Prerequisites

The script checks and will exit if any of these are missing. Install them first:

| Tool    | Purpose                                              | Install / Docs                                                |
| ------- | ---------------------------------------------------- | ------------------------------------------------------------- |
| Docker  | Container runtime used by kind                       | https://docs.docker.com/get-docker/                           |
| kind    | Run Kubernetes in Docker                             | https://kind.sigs.k8s.io/docs/user/quick-start/               |
| kubectl | Kubernetes CLI                                       | https://kubernetes.io/docs/tasks/tools/                       |
| Helm    | Package manager for Kubernetes                       | https://helm.sh/docs/intro/install/                           |
| jq      | JSON processing in shell                             | https://jqlang.github.io/jq/download/                         |
| base64  | Secret decoding (usually preinstalled via coreutils) | macOS/Linux: normally built-in (test with `base64 --version`) |

Optional (used later): `mongosh`, `pgcli`, `vault` CLI, etc.

Homebrew (macOS/Linux) quick installs:

```bash
brew install kind kubectl helm jq
```

Docker Desktop (macOS) via Homebrew Cask:

```bash
brew install --cask docker
```

After installing Docker Desktop, start it once so the daemon is running.

---

## 🚀 Quick Start

Show help (also printed when no args supplied):

```bash
./create-cluster.sh
```

Create a cluster (interactive prompts follow):

```bash
./create-cluster.sh create mycluster
# or shorthand
./create-cluster.sh c mycluster
```

During the prompts you can choose:

-   Kubernetes version (must match one of the listed supported versions)
-   Number of control planes & workers
-   Whether to install ArgoCD (Helm) immediately
-   (Nginx ingress for kind is auto-installed)

When finished you get:

-   `clusters/clusterinfo-<name>.txt` – summarized settings, generated passwords, helpful commands
-   `clusters/kubeconfig-<name>.config` – per-cluster kubeconfig file

Export kubeconfig for kubectl convenience:

```bash
export KUBECONFIG="$(pwd)/clusters/kubeconfig-mycluster.config"
kubectl get nodes
```

Open ArgoCD (if installed):

```text
http://argocd.localtest.me          # First / only cluster
http://argocd.localtest.me:<port>   # If multiple clusters (see clusterinfo file)
```

Username: `admin` Password: Listed in clusterinfo file (extracted from the bootstrap secret)

Install Nyancat sample app after cluster creation (if you skipped initially):

```bash
./create-cluster.sh iac   # install-app-nyancat
```

Delete the cluster:

```bash
./create-cluster.sh delete mycluster
# or shorthand
./create-cluster.sh d mycluster
```

List clusters:

```bash
./create-cluster.sh ls
```

Fetch (regenerate) kubeconfig file later:

```bash
./create-cluster.sh kc mycluster
```

See full cluster details (cluster info + kind config used):

```bash
./create-cluster.sh info mycluster   # alias: i
```

---

## 🧩 Command Reference

Kind / cluster lifecycle:

| Action            | Alias | Description                                              |
| ----------------- | ----- | -------------------------------------------------------- |
| create <name>     | c     | Interactive creation workflow                            |
| list              | ls    | List kind clusters                                       |
| details           | dt    | Live k8s cluster info (nodes, pods, services, ingresses) |
| info <name>       | i     | Show saved cluster configuration & kind config file      |
| kubeconfig <name> | kc    | Write kubeconfig file for cluster                        |
| delete <name>     | d     | Delete cluster (confirmation prompt)                     |
| help              | h     | Show help                                                |

Helm installers (imperative, alphabetical):

```
iha   (install-helm-argocd)         ihrcc (install-helm-ceph-cluster)
ihrco (install-helm-ceph-operator)  ihcr  (install-helm-crossplane)
ihf   (install-helm-falco)          ihm   (install-helm-metallb)
ihmin (install-helm-minio)          ihmdbi (install-helm-mongodb-instance)
ihmdb (install-helm-mongodb-operator) ihnats (install-helm-nats)
ihn   (install-helm-nginx)          ihnfs (install-helm-nfs)
ihpa  (install-helm-pgadmin)        ihpg  (install-helm-postgres)
ihrs  (install-helm-redis-stack)    iht   (install-helm-trivy)
ihv   (install-helm-vault)
```

ArgoCD Application installers (GitOps style, alphabetical):

```
iarcc (rook ceph cluster)    iarco (rook ceph operator)   iac   (nyancat)
iacm  (cert-manager)         iacr  (crossplane)           iaf   (falco)
iakv  (kubeview)             iam   (metallb)              iamin (minio)
iamdbi (mongodb instance)    iamdb (mongodb operator)     ian   (nginx controller)
ianats (nats)                ianfs (nfs)                  iaoc  (opencost)
iapga (pgadmin)              iapg  (postgres operator)    iap   (kube-prometheus-stack)
iars  (redis stack)          iat   (trivy)                iav   (vault)
```

> All commands map 1:1 to script functions; see `scripts/core/config.sh` for authoritative list.

---

## 🌐 Ingress & Hostnames

-   `localtest.me` resolves every `*.localtest.me` domain to `127.0.0.1`, removing the need for editing `/etc/hosts`.
-   Single cluster: apps are directly at `http://<app>.localtest.me`
-   Multiple clusters: first retains ports 80/443, subsequent clusters get randomly assigned host ports (recorded in the `clusterinfo-*` file). Use `http://<app>.localtest.me:<cluster_http_port>`.

Common hostnames:
| Component | URL (single cluster) |
|-----------|----------------------|
| ArgoCD | http://argocd.localtest.me |
| Nyancat sample | http://nyancat.localtest.me |

---

## 🔐 Secrets & Access Notes

-   ArgoCD admin password extracted from the initial secret and logged to the cluster info file.
-   Generated cluster info files may contain credentials – treat the `clusters/` folder as sensitive if you reuse values.
-   Vault install auto-inits & unseals, writing `vault-init.json` (contains unseal keys + root token). Guard or delete this file if not just experimenting.

---

## 🧪 Post-Install Examples

Port-forward Grafana (kube-prometheus-stack):

```bash
kubectl port-forward -n prometheus svc/prometheus-grafana 30000:80
open http://localhost:30000  # macOS helper (or xdg-open on Linux)
```

Access Postgres (CloudNativePG):

```bash
kubectl port-forward -n postgres-cluster svc/postgres-cluster-rw 5432:5432
pgcli -h localhost -U postgres -p 5432  # password from cluster info or secret
```

Access MongoDB instance:

```bash
kubectl port-forward -n mongodb svc/mongodb-instance-svc 27017:27017
mongosh "mongodb://appuser:SuperSecret@localhost:27017/appdb?replicaSet=mongodb-instance&directConnection=true"
```

Access Vault:

```bash
kubectl port-forward -n vault svc/vault 8200:8200
open http://localhost:8200
```

---

## ♻️ Cleanup

```bash
./create-cluster.sh delete mycluster
kind get clusters           # verify removal
```

Remove generated artifacts:

```bash
rm clusters/clusterinfo-mycluster.txt clusters/kubeconfig-mycluster.config
```

---

## 🛠 Troubleshooting

| Issue                                 | Hint                                                                                     |
| ------------------------------------- | ---------------------------------------------------------------------------------------- |
| Script says a prerequisite is missing | Install it & re-run (brew / apt etc.)                                                    |
| Ports 80/443 already in use           | Likely another kind cluster – new cluster auto-uses random ports; check clusterinfo file |
| ArgoCD UI not reachable               | Ensure ingress controller pods are Ready; `kubectl get pods -n ingress-nginx`            |
| Application stuck syncing             | Check ArgoCD `argocd app list` & pod logs in the target namespace                        |
| Vault unseal problems                 | Re-run unseal using keys in `vault-init.json`                                            |

---

## 🤝 Contributing

PRs welcome! Suggested improvements:

-   Add automated tests / linting
-   Expand OS compatibility (Windows PowerShell native)
-   Additional example ArgoCD apps
-   Observability stack variants (e.g., Loki, Tempo, Jaeger)

---

## 📄 License

This project is licensed under the terms of the [LICENSE](./LICENSE).

---

## 📚 More Docs

Additional walkthrough & background: [docs/k8s.md](./docs/k8s.md)

New to Kubernetes? Start here: [docs/kubernetes-101.md](./docs/kubernetes-101.md)

What do the optional apps provide? [docs/kubernetes-apps-overview.md](./docs/kubernetes-apps-overview.md)

ArgoCD & App-of-Apps pattern: [docs/argocd-app-of-apps.md](./docs/argocd-app-of-apps.md)

---

Happy clustering! 🧪
