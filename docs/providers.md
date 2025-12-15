# Multi-Provider Guide

## Overview

K8s-local now supports multiple Kubernetes providers with a unified interface. All your favorite tools (ArgoCD, Helm charts, apps) work identically across all providers.

## Supported Providers

### 1. kind (default)
- **What**: Kubernetes in Docker
- **Best for**: Quick local testing
- **Boot time**: ~30 seconds
- **Installation**: `brew install kind`

### 2. talos
- **What**: Talos Linux (immutable, API-driven Kubernetes)
- **Best for**: Production-like local testing
- **Boot time**: ~60 seconds
- **Installation**: `brew install siderolabs/tap/talosctl`

## Basic Usage

### Creating Clusters

```bash
# Interactive mode - you'll be prompted to choose provider
./kl.sh create mycluster

# Example interactive flow:
# Available providers:
#   1) kind   - Kubernetes in Docker (fast, default)
#   2) talos  - Talos Linux (immutable, production-like)
# Select provider (1 for kind, 2 for talos) [default: 1]: 2
# ✅ Provider set to: talos

# Or specify provider via flag (non-interactive)
./kl.sh create mycluster --provider talos
./kl.sh create mycluster --provider kind
```

### Listing Clusters

```bash
./kl.sh list
# Output:
#   mycluster (kind)
#   prod-test (talos)
```

### Deleting Clusters

```bash
# Auto-detects provider from metadata
./kl.sh delete mycluster
```

### Getting Cluster Details

```bash
# Works with any provider
./kl.sh details mycluster
./kl.sh k8sdetails mycluster
```

## Provider-Agnostic Features

These features work identically on **all providers**:

### Helm Installations
```bash
# Works on kind or talos clusters
./kl.sh install helm argocd
./kl.sh install helm valkey,nats
./kl.sh install helm prometheus --dry-run
```

### ArgoCD Applications
```bash
# Works on kind or talos clusters
./kl.sh install apps nyancat
./kl.sh install apps prometheus,mongodb
./kl.sh install apps metallb --dry-run
```

### Kubectl Operations
```bash
# Get kubeconfig (works for any provider)
./kl.sh kubeconfig mycluster

# Use the kubeconfig
export KUBECONFIG=$(pwd)/clusters/mycluster/kubeconfig
kubectl get nodes
kubectl get pods --all-namespaces
```

## Cluster File Structure

Each cluster has its own organized directory:

```
clusters/
└── mycluster/
    ├── provider.txt           # Provider type (kind or talos)
    ├── clusterinfo.txt        # Cluster metadata
    ├── kubeconfig             # Kubernetes config
    ├── config.yaml            # kind config (for kind clusters)
    └── talos/                 # Talos configs (for talos clusters)
        ├── controlplane.yaml
        ├── worker.yaml
        └── talosconfig
```

**Benefits:**
- All cluster files in one place
- Easy to backup/restore entire cluster config
- Clear separation between clusters
- Simple cleanup (delete entire directory)

## Provider-Specific Features

### kind-Specific

**Fast Cluster Creation:**
```bash
./kl.sh create quick-test --provider kind
# Ready in ~30 seconds
```

**Multiple Kubernetes Versions:**
- Supports v1.25 through v1.34
- Specified during cluster creation

### talos-Specific

**Access Talos API:**
```bash
# Get node IPs
docker ps --filter "name=mycluster-" --format "{{.Names}}: {{.Ports}}"

# Use talosctl
talosctl --talosconfig clusters/mycluster/talos/talosconfig \
  --nodes <node-ip> get services

# View Talos logs
talosctl --talosconfig clusters/mycluster/talos/talosconfig \
  --nodes <node-ip> logs
```

**Immutable Infrastructure:**
- No SSH access to nodes
- All configuration via Talos API
- Minimal attack surface

## Cluster Metadata

Each cluster stores its provider information in an organized directory structure (see "Cluster File Structure" section above for details).

The cluster metadata includes:
- Provider type (kind or talos)
- Cluster configuration
- Kubeconfig
- Provider-specific configs

## Multi-Cluster Scenarios

### Running Multiple Clusters

```bash
# Create multiple clusters with different providers
./kl.sh create dev --provider kind
./kl.sh create staging --provider talos

# List all clusters
./kl.sh list
# Output:
#   dev (kind)
#   staging (talos)

# Install same components on both
export KUBECONFIG=$(pwd)/clusters/dev/kubeconfig
./kl.sh install helm argocd

export KUBECONFIG=$(pwd)/clusters/staging/kubeconfig
./kl.sh install helm argocd
```

### Port Mapping with Multiple Clusters

When running multiple clusters:
- First cluster: Uses ports 80/443
- Additional clusters: Get random high ports (8080+)

```bash
# Check ports in cluster info
cat clusters/mycluster/clusterinfo.txt | grep port
# Output:
# Cluster http port: 8080
# Cluster https port: 8443
```

Access apps with port:
```bash
# First cluster
http://argocd.localtest.me

# Second cluster
http://argocd.localtest.me:8080
```

## Switching Between Providers

You can easily switch between providers for testing:

```bash
# Test feature on kind (fast)
./kl.sh create test-feature --provider kind
# ... do testing ...
./kl.sh delete test-feature

# Test same feature on talos (production-like)
./kl.sh create test-feature --provider talos
# ... do testing ...
./kl.sh delete test-feature
```

## Comparison Table

| Feature | kind | talos |
|---------|------|-------|
| Boot time | ~30s | ~60s |
| Operating System | Generic container | Talos Linux |
| Configuration | kind YAML | Talos machine config |
| SSH access | Yes | No (API only) |
| Immutable | No | Yes |
| Security | Standard | Enhanced |
| Best for | Quick testing | Production-like testing |
| K8s versions | Selectable (v1.25-v1.34) | Latest stable only |
| Version selection | Interactive prompt | Auto (no prompt) |
| HA control plane | Yes | Yes |
| Custom CNI | Limited | Full support |

## Troubleshooting

### kind Issues

**Cluster won't start:**
```bash
# Check Docker is running
docker ps

# Check kind clusters
kind get clusters

# Delete and recreate
kind delete cluster --name mycluster
./kl.sh create mycluster --provider kind
```

### talos Issues

**Talos nodes not ready:**
```bash
# Check container status
docker ps --filter "name=mycluster-"

# Check Talos node status
talosctl --talosconfig clusters/mycluster-talos/talosconfig \
  --nodes <node-ip> get nodes

# View Talos logs
talosctl --talosconfig clusters/mycluster/talos/talosconfig \
  --nodes <node-ip> logs
```

**Can't access Kubernetes API:**
```bash
# Verify kubeconfig
export KUBECONFIG=$(pwd)/clusters/mycluster/kubeconfig
kubectl cluster-info

# Check API server is running
docker ps | grep controlplane
```

### General Issues

**Provider not found:**
```bash
# Verify provider tool is installed
kind version          # for kind
talosctl version      # for talos

# Install missing provider
brew install kind
brew install siderolabs/tap/talosctl
```

**Kubeconfig issues:**
```bash
# Regenerate kubeconfig
./kl.sh kubeconfig mycluster

# Set environment variable
export KUBECONFIG=$(pwd)/clusters/mycluster/kubeconfig

# Verify
kubectl get nodes
```

## Advanced Usage

### Custom Network Configuration (kind)

kind clusters use default networking. For custom configs, edit the generated config file before creation.

### Talos Machine Config Customization

After cluster creation, you can modify Talos configs:

```bash
# Edit controlplane config
vim clusters/mycluster/talos/controlplane.yaml

# Apply changes
talosctl --talosconfig clusters/mycluster/talos/talosconfig \
  apply-config --nodes <node-ip> \
  --file clusters/mycluster/talos/controlplane.yaml
```

## Future Providers

The provider abstraction makes it easy to add new providers:

**Potential additions:**
- k3d (k3s in Docker)
- minikube
- microk8s
- k0s

Each would implement the same interface and work with all existing tools!

## Getting Help

```bash
# Show help
./kl.sh help

# List available Helm components
./kl.sh helm list

# List available ArgoCD apps
./kl.sh apps list

# Check prerequisites
./kl.sh
```

## Summary

The multi-provider architecture gives you:

✅ **Flexibility**: Choose the right provider for your use case
✅ **Consistency**: Same commands work across all providers
✅ **Reusability**: All Helm charts and apps work everywhere
✅ **Extensibility**: Easy to add new providers
✅ **No Lock-in**: Switch providers anytime

Start using it today:
```bash
./kl.sh create my-cluster --provider talos
```
