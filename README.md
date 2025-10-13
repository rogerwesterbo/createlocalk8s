# K8S Local

```
██╗  ██╗ █████╗ ███████╗    ██╗      ██████╗  ██████╗ █████╗ ██╗
██║ ██╔╝██╔══██╗██╔════╝    ██║     ██╔═══██╗██╔════╝██╔══██╗██║
█████╔╝ ╚█████╔╝███████╗    ██║     ██║   ██║██║     ███████║██║
██╔═██╗ ██╔══██╗╚════██║    ██║     ██║   ██║██║     ██╔══██║██║
██║  ██╗╚█████╔╝███████║    ███████╗╚██████╔╝╚██████╗██║  ██║███████╗
╚═╝  ╚═╝ ╚════╝ ╚══════╝    ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝
```

Local Kubernetes Cluster Manager (kind + talos + docker)

> **⚠️ IMPORTANT: FOR DEVELOPMENT AND TESTING ONLY**
>
> These clusters are designed for local development, testing, and learning purposes.
> **DO NOT use in production environments.** They lack the security hardening, high availability,
> and operational features required for production workloads.

New to Kubernetes? Start here: [docs/kubernetes-101.md](./docs/kubernetes-101.md)

Need more info about ArgoCD (perhaps the most central part except kubernetes?) & App-of-Apps pattern: [docs/argocd-app-of-apps.md](./docs/argocd-app-of-apps.md)

Just need some information about the apps, see here: [docs/kubernetes-apps-overview.md](./docs/kubernetes-apps-overview.md)

Create and experiment with local Kubernetes clusters using [kind](https://kind.sigs.k8s.io/) or [Talos](https://www.talos.dev/) + Docker, then bootstrap common platform components (ArgoCD, ingress, databases, security, storage, cost / monitoring, etc.) either directly with Helm or via ArgoCD Applications.

> Currently supports macOS & Linux (also works under WSL2). Cygwin/MSYS shells may work but are not officially tested.

## 🚀 Multi-Provider Support

Choose your Kubernetes provider:

-   **kind** (default) - Kubernetes in Docker, fast and lightweight
-   **talos** - Talos Linux in Docker, immutable infrastructure

📖 **[Read the full Multi-Provider Guide](./docs/providers.md)**

---

```bash
$ ./kl.sh


██╗  ██╗ █████╗ ███████╗    ██╗      ██████╗  ██████╗ █████╗ ██╗
██║ ██╔╝██╔══██╗██╔════╝    ██║     ██╔═══██╗██╔════╝██╔══██╗██║
█████╔╝ ╚█████╔╝███████╗    ██║     ██║   ██║██║     ███████║██║
██╔═██╗ ██╔══██╗╚════██║    ██║     ██║   ██║██║     ██╔══██║██║
██║  ██╗╚█████╔╝███████║    ███████╗╚██████╔╝╚██████╗██║  ██║███████╗
╚═╝  ╚═╝ ╚════╝ ╚══════╝    ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝

    Local Kubernetes Cluster Manager (kind + talos + docker)


Cluster Management:
  list                            alias: ls      Show all clusters (kind & talos)
  create [cluster-name]           alias: c       Create a local cluster (kind or talos)
  details <cluster-name>          alias: dt      Show details for a cluster
  k8sdetails <cluster-name>       alias: k8s     Show detailed Kubernetes resources info
  kubeconfig <cluster-name>       alias: kc      Get kubeconfig for a cluster by name
  delete <cluster-name>           alias: d       Delete a cluster by name
  help                            alias: h       Print this Help

Provider Options:
  --provider <kind|talos>                        Specify cluster provider (skips interactive prompt)

Examples:
  ./kl.sh create mycluster                       Create cluster (interactive provider selection)
  ./kl.sh create mycluster --provider talos      Create talos cluster (skip provider prompt)
  ./kl.sh details mycluster                      Show details for cluster 'mycluster'
  ./kl.sh k8sdetails mycluster                   Show K8s resources for cluster 'mycluster'
  ./kl.sh delete mycluster                       Delete cluster 'mycluster'

Helm installations:
  helm list                                List available Helm components
  install helm redis-stack,nats            Install one or more Helm components
  install helm redis-stack --dry-run       Dry run (show what would be installed)

ArgoCD application installations:
  apps list                                List available ArgoCD app components
  install apps nyancat,prometheus          Install one or more ArgoCD apps
  install apps nats,redis-stack --dry-run  Dry run for ArgoCD apps

Notes:
  - Parameters in [brackets] are optional
  - Parameters in <brackets> are required
  - Use comma-separated lists (no spaces): redis-stack,nats
  - Components are installed in the order specified
  - Use --dry-run to preview changes before applying

dependencies: docker, kind, kubectl, jq, base64 and helm

Current date and time in Linux Mon Oct 13 23:29:08 CEST 2025
```

## ✨ Key Features

-   **Multiple script names**: Use `./kl.sh` (short), `./k8s-local.sh`, or `./create-cluster.sh` (legacy)
-   **Dynamic shell completion**: Bash, Zsh, Fish (commands + components discovered at runtime)
-   **Multi-Provider Support**: Choose between kind and Talos providers (interactive or via `--provider` flag)
-   Interactive cluster creation (name, control planes, workers, Kubernetes version, provider selection)
-   Supported Kubernetes versions:
    -   **kind**: v1.25.x → v1.34.x (see `scripts/variables.sh` for full list)
    -   **talos**: v1.30.x → v1.34.x (see `scripts/variables.sh` for full list)
-   **Organized cluster storage**: Each cluster gets its own directory under `clusters/<cluster-name>/`
-   Automatic port mapping adjustment when multiple clusters run simultaneously (avoids 80/443 conflicts)
-   Optional automatic ArgoCD + Nginx Ingress install during cluster creation
-   Post-create helper to install a sample Nyancat app (demo ingress + ArgoCD)
-   Rich subcommands to list, inspect, delete clusters & fetch kubeconfig
-   **Registry-based installers**: List and install Helm/ArgoCD components with simple commands
-   19 Helm installers: ArgoCD, Crossplane, Rook Ceph, Falco, Trivy, Vault, MetalLB, MinIO, NFS, MongoDB Operator, CNPG, PgAdmin, Redis Stack, NATS, cert-manager, kube-prometheus-stack, kubeview, nginx-ingress, OpenCost
-   22 ArgoCD Application installers (GitOps style): monitoring (Prometheus), databases, security, storage, cost monitoring, etc.
-   **Dry-run mode**: Preview what will be installed with `--dry-run`
-   Generates per-cluster info + kubeconfig files under `clusters/<cluster-name>/`
-   Consistent colored output & spinners, with readiness waits for core components
-   Uses `localtest.me` wildcard DNS (no /etc/hosts changes needed)

---

## 🔧 Provider-Specific Features

### Kind Provider

-   Fast cluster creation (~30 seconds)
-   Multiple Kubernetes versions supported (v1.25-v1.34)
-   Port mapping for ingress access
-   Multi-cluster support on same host

### Talos Provider

-   **Immutable Infrastructure**: Talos Linux runs Kubernetes without a traditional OS
-   **API-Driven**: All configuration via declarative YAML
-   **Secure by Default**: Minimal attack surface, no SSH access
-   **Production-Like**: Closer to real production Talos deployments
-   **Docker-Based**: Runs Talos nodes as Docker containers for local development

**Network Architecture:**

-   **Single control plane**: Uses hostNetwork mode with direct port exposure
-   **Multi control plane**: Uses MetalLB + HAProxy proxy container for load balancing
    -   HAProxy container forwards traffic from host ports to MetalLB LoadBalancer IP
    -   Automatic port assignment to avoid conflicts with other clusters

**Talos-Specific Commands:**

```bash
# Get Talos node IPs
docker ps --filter "name=mycluster-" --format "{{.Names}}: {{.Ports}}"

# View ingress proxy container (multi-control-plane only)
docker logs mycluster-ingress-proxy

# Access Talos API directly
talosctl --talosconfig clusters/mycluster/talos/talosconfig \
  --nodes <node-ip> get services

# View Talos logs
talosctl --talosconfig clusters/mycluster/talos/talosconfig \
  --nodes <node-ip> logs
```

**Key Differences:**

| Feature             | kind              | talos                   |
| ------------------- | ----------------- | ----------------------- |
| Boot time           | ~30s              | ~60s                    |
| OS                  | Generic container | Talos Linux             |
| Config format       | kind YAML         | Talos machine config    |
| SSH access          | Yes (to nodes)    | No (API only)           |
| K8s versions        | v1.25-v1.34       | v1.30-v1.34             |
| Ingress (single CP) | Port mapping      | hostNetwork mode        |
| Ingress (multi CP)  | Port mapping      | MetalLB + HAProxy       |
| Best for            | Quick testing     | Production-like testing |

---

## 🧱 Repository Layout (selected)

```
kl.sh                      # Short entry point (recommended)
k8s-local.sh               # Full name entry point
create-cluster.sh          # Legacy entry point (backward compatible)
scripts/
	variables.sh             # Global defaults (versions, colors, flags)
	core/
		config.sh              # Help + command routing + logo
		cluster.sh             # Cluster operations (provider-agnostic)
		cluster-common.sh      # Provider-agnostic K8s operations
		utils.sh               # Prereq & utility helpers
	providers/
		provider-interface.sh  # Provider abstraction layer
		kind-provider.sh       # Kind provider implementation
		talos-provider.sh      # Talos provider implementation
	installers/
		registry.sh            # Component registry (Helm + ArgoCD apps)
		helm.sh                # Helm installer functions
		apps.sh                # ArgoCD Application installer functions
completions/               # Shell completion scripts (bash, zsh, fish)
	install-completion.sh    # Automated completion installer
configs/apps/manifests/    # ArgoCD Application YAMLs & supporting manifests
clusters/                  # Generated: kubeconfig & clusterinfo-* per cluster
docs/                      # Additional documentation & diagram(s)
```

---

## ✅ Prerequisites

The script checks and will exit if any of these are missing. Install them first:

### Core Prerequisites (all providers)

| Tool    | Purpose                                              | Install / Docs                                                |
| ------- | ---------------------------------------------------- | ------------------------------------------------------------- |
| Docker  | Container runtime                                    | https://docs.docker.com/get-docker/                           |
| kubectl | Kubernetes CLI                                       | https://kubernetes.io/docs/tasks/tools/                       |
| Helm    | Package manager for Kubernetes                       | https://helm.sh/docs/intro/install/                           |
| jq      | JSON processing in shell                             | https://jqlang.github.io/jq/download/                         |
| base64  | Secret decoding (usually preinstalled via coreutils) | macOS/Linux: normally built-in (test with `base64 --version`) |

### Provider-Specific Prerequisites

| Provider | Tool     | Purpose                    | Install / Docs                                             |
| -------- | -------- | -------------------------- | ---------------------------------------------------------- |
| kind     | kind     | Run Kubernetes in Docker   | https://kind.sigs.k8s.io/docs/user/quick-start/            |
| talos    | talosctl | Talos Linux management CLI | https://www.talos.dev/latest/introduction/getting-started/ |

Optional (used later): `mongosh`, `pgcli`, `vault` CLI, etc.

Homebrew (macOS/Linux) quick installs:

```bash
# Core tools
brew install kubectl helm jq

# Provider tools (install what you need)
brew install kind                      # for kind provider
brew install siderolabs/tap/talosctl   # for talos provider
```

Docker Desktop (macOS) via Homebrew Cask:

```bash
brew install --cask docker
```

After installing Docker Desktop, start it once so the daemon is running.

---

## 🚀 Quick Start

### Installation

**Optional**: Install shell completion for better experience:

```bash
./completions/install-completion.sh
source ~/.zshrc  # or ~/.bashrc for bash
```

Now you'll have tab completion for all commands!

### Basic Usage

Show help (also printed when no args supplied):

```bash
./kl.sh help
# or use the full name
./k8s-local.sh help
# or legacy name
./create-cluster.sh help
```

Create a cluster (interactive prompts follow):

```bash
# Interactive mode - choose provider during creation
./kl.sh create mycluster
# or shorthand
./kl.sh c mycluster

# You'll be prompted:
# Available providers:
#   1) kind   - Kubernetes in Docker (fast, default)
#   2) talos  - Talos Linux (immutable, production-like)
# Select provider (1 for kind, 2 for talos) [default: 1]:

# Or specify provider via flag (skip provider prompt)
./kl.sh create mycluster --provider talos
./kl.sh create mycluster --provider kind
```

During the prompts you can choose:

-   **Provider** (kind or talos)
-   **Kubernetes version** (kind only - supports v1.25-v1.34; talos uses latest stable)
-   **CNI** (Container Network Interface): default, cilium, or calico
-   **Multus CNI** (optional add-on for multiple network interfaces per pod)
-   Number of control planes & workers
-   Whether to install ArgoCD (Helm) immediately
-   (Nginx ingress is auto-installed for all providers)

### 🌐 CNI (Container Network Interface) Options

Choose your networking layer during cluster creation:

| CNI         | Description                             | Best For                             | Documentation                      |
| ----------- | --------------------------------------- | ------------------------------------ | ---------------------------------- |
| **default** | Provider's default CNI                  | Quick testing, simple setups         | -                                  |
| **cilium**  | eBPF-based, high-performance networking | Observability, security, performance | [docs/cilium.md](./docs/cilium.md) |
| **calico**  | Policy-driven networking                | Network policies, multi-tenancy      | [docs/calico.md](./docs/calico.md) |

**Multus CNI Add-on** (available after selecting Cilium or Calico):

-   Enables multiple network interfaces per pod
-   **thin plugin** (recommended): Lightweight, delegates to primary CNI
-   **thick plugin**: Standalone with built-in IPAM
-   📚 [Read Multus CNI Guide](./docs/multus-cni.md)

**Example cluster creation with CNI:**

```bash
./kl.sh create mycluster --provider=talos
# Prompts will include:
# Use custom CNI? (default/cilium/calico) (default: default): cilium
# Install Multus CNI? (yes/no) (default: no): yes
# Multus plugin type? (thin/thick) (default: thin): thin
```

📊 **[See detailed cluster creation flow diagram](./docs/cluster-creation-flow.md)**

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
./kl.sh install apps nyancat
```

Delete the cluster:

```bash
./kl.sh delete mycluster
# or shorthand
./kl.sh d mycluster
```

List clusters:

```bash
./kl.sh ls
```

Fetch (regenerate) kubeconfig file later:

```bash
./kl.sh kc mycluster
```

See full cluster details (cluster info + kind config used):

```bash
./kl.sh info mycluster   # alias: i
```

---

## 🧩 Command Reference

### Cluster Lifecycle

| Action / Aliases       | Description                                              |
| ---------------------- | -------------------------------------------------------- |
| create (c) <name>      | Interactive creation workflow                            |
| list (ls)              | List kind clusters                                       |
| details (dt)           | Live k8s cluster info (nodes, pods, services, ingresses) |
| info (i) <name>        | Show saved cluster configuration & kind config summary   |
| kubeconfig (kc) <name> | Write kubeconfig file for cluster                        |
| config <name>          | Show raw kind config used (if persisted)                 |
| start <name>           | Start a stopped cluster (noop if not supported)          |
| stop <name>            | Stop a running cluster (noop if not supported)           |
| delete (d) <name>      | Delete cluster (confirmation)                            |
| help (h)               | Show help                                                |

### Component Management

**List available components:**

```bash
./kl.sh helm list              # List all Helm components
./kl.sh apps list              # List all ArgoCD applications
```

**Install components (single or multiple):**

```bash
# Install single Helm component
./kl.sh install helm redis-stack

# Install multiple Helm components (comma-separated)
./kl.sh install helm redis-stack,nats,metallb

# Install ArgoCD application
./kl.sh install apps prometheus

# Install multiple apps
./kl.sh install apps nyancat,prometheus,mongodb

# Dry-run mode (preview what will be installed)
./kl.sh install helm redis-stack --dry-run
./kl.sh install apps prometheus,mongodb --dry-run
```

**Available Helm components** (19):

-   `argocd` - ArgoCD GitOps controller
-   `cert-manager` - Certificate management
-   `cnpg` - CloudNativePG operator
-   `crossplane` - Cloud native control plane
-   `falco` - Runtime security
-   `hashicorp-vault` - Secrets management
-   `kube-prometheus-stack` - Prometheus monitoring
-   `kubeview` - Cluster visualizer
-   `metallb` - Load balancer
-   `minio` - S3-compatible storage
-   `mongodb-operator` - MongoDB operator
-   `nats` - NATS messaging
-   `nfs` - NFS provisioner
-   `nginx-ingress` - NGINX ingress controller
-   `opencost` - Cost monitoring
-   `pgadmin` - PostgreSQL admin UI
-   `redis-stack` - Redis Stack server
-   `rook-ceph-operator` - Rook Ceph operator
-   `trivy` - Security scanner

**Available ArgoCD apps** (22):

-   `nyancat` - Sample demo app
-   `prometheus` - Kube Prometheus Stack
-   `cert-manager` - Cert Manager app
-   `cnpg-cluster` - CNPG cluster instance
-   `crossplane` - Crossplane app
-   `falco` - Falco security app
-   `hashicorp-vault` - Vault app
-   `kubeview` - KubeView app
-   `metallb` - MetalLB app
-   `minio` - MinIO app
-   `mongodb` - MongoDB instance
-   `mongodb-operator` - MongoDB operator app
-   `nats` - NATS app
-   `nfs` - NFS provisioner app
-   `opencost` - OpenCost app
-   `pg-ui` - PostgreSQL UI
-   `pgadmin` - PgAdmin app
-   `redis-stack` - Redis Stack app
-   `rook-ceph-cluster` - Rook Ceph cluster
-   `rook-ceph-operator` - Rook Ceph operator app
-   `trivy` - Trivy scanner app
-   `coredns` - CoreDNS app

> Use tab completion to discover available components! Run `./completions/install-completion.sh` to enable it.

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

## 🎯 Shell Completion

Tab completion makes it easy to discover and use commands:

```bash
# Install completion (auto-detects your shell)
./completions/install-completion.sh

# Reload your shell
source ~/.zshrc     # for zsh
source ~/.bashrc    # for bash
```

**Supported shells**: Bash 3.2+, Zsh 5.0+, Fish 3.0+

**What you get:**

-   Tab completion for all commands
-   Component name completion with descriptions (zsh/fish)
-   Flag completion (--dry-run)
-   Works with all script names: `./kl.sh`, `./k8s-local.sh`, `./create-cluster.sh`
-   Dynamic extraction of commands (no manual sync needed)
-   Live parsing of available Helm components & ArgoCD apps (`helm list` / `apps list`)

See [docs/shell-completion.md](./docs/shell-completion.md) for detailed installation and usage.

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

| Issue                                 | Hint                                                                                |
| ------------------------------------- | ----------------------------------------------------------------------------------- |
| Script says a prerequisite is missing | Install it & re-run (brew / apt etc.)                                               |
| Ports 80/443 already in use           | Likely another cluster – new cluster auto-uses random ports; check clusterinfo file |
| ArgoCD UI not reachable               | Ensure ingress controller pods are Ready; `kubectl get pods -n ingress-nginx`       |
| Talos multi-CP ingress not working    | Check HAProxy proxy container: `docker logs <cluster>-ingress-proxy`                |
| Application stuck syncing             | Check ArgoCD `argocd app list` & pod logs in the target namespace                   |
| Vault unseal problems                 | Re-run unseal using keys in `vault-init.json`                                       |

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

**Getting Started:**

-   New to Kubernetes? Start here: [docs/kubernetes-101.md](./docs/kubernetes-101.md)
-   Additional walkthrough & background: [docs/k8s.md](./docs/k8s.md)

**Multi-Provider:**

-   **Multi-Provider Guide**: [docs/providers.md](./docs/providers.md)
-   Implementation details: [MULTI_PROVIDER_IMPLEMENTATION.md](./MULTI_PROVIDER_IMPLEMENTATION.md)

**Components & Patterns:**

-   What do the optional apps provide? [docs/kubernetes-apps-overview.md](./docs/kubernetes-apps-overview.md)
-   ArgoCD & App-of-Apps pattern: [docs/argocd-app-of-apps.md](./docs/argocd-app-of-apps.md)

**Shell Completion:**

-   Installation & usage guide: [docs/shell-completion.md](./docs/shell-completion.md)
-   Quick install: [completions/README.md](./completions/README.md)

---

Happy clustering! 🧪
