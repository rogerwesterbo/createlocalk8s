# Multus CNI Guide

## Overview

Multus CNI is a meta-CNI plugin that enables attaching multiple network interfaces to pods in Kubernetes. It acts as a "multiplexer" that can call other CNI plugins, allowing pods to have multiple network connections beyond the default Kubernetes network.

## What is Multus CNI?

Multus (Latin for "multiple") is a CNI plugin that enables Kubernetes pods to have:

-   Multiple network interfaces
-   Different networks per interface
-   Specialized network configurations (SR-IOV, macvlan, bridge, etc.)
-   Isolation between management and data plane traffic

**Key Concept**: Multus doesn't replace your primary CNI (Cilium/Calico) — it works **alongside** it, allowing additional network interfaces.

## Architecture

```
┌─────────────────────────────────────────┐
│              Pod                         │
├─────────────────────────────────────────┤
│  eth0 (default)  │  net1  │  net2       │  ← Multiple interfaces
│  via Cilium      │  via   │  via        │
│  or Calico       │ macvlan│ SR-IOV      │
└─────────────────────────────────────────┘
         ↓              ↓         ↓
    ┌────────┐    ┌─────────┐ ┌─────────┐
    │Primary │    │Additional│ │Additional│
    │  CNI   │    │ Network  │ │ Network  │
    │(Cilium)│    │ (macvlan)│ │ (SR-IOV) │
    └────────┘    └─────────┘ └─────────┘
```

## Plugin Types

### Thin Plugin (Recommended)

**What it is:**

-   Lightweight shim layer (~1MB)
-   Delegates network setup to other CNI plugins
-   Depends on your primary CNI for the default interface

**How it works:**

1. Creates default interface using primary CNI (Cilium/Calico)
2. Calls additional CNI plugins for extra interfaces
3. Minimal overhead, simple configuration

**Best for:**

-   ✅ Most use cases
-   ✅ Standard Kubernetes clusters
-   ✅ When you want simplicity
-   ✅ macvlan, bridge, or other CNI plugins

**Example:**

```
Pod eth0 → Cilium (primary CNI, managed by thin Multus)
Pod net1 → macvlan (additional network, managed by thin Multus)
```

### Thick Plugin (Advanced)

**What it is:**

-   Standalone binary with full CNI capabilities
-   Built-in IPAM (IP Address Management)
-   Can manage networks independently

**How it works:**

1. Manages all interfaces directly
2. Includes its own network configuration logic
3. More features but more complex

**Best for:**

-   ✅ Advanced networking scenarios
-   ✅ When you need full control
-   ✅ Custom IPAM requirements
-   ✅ Independent network management
-   ❌ Not needed for most users

**Example:**

```
Pod eth0 → Thick Multus manages directly with IPAM
Pod net1 → Thick Multus manages directly with IPAM
```

## When to Use Multus CNI

### ✅ Use Multus if you need:

1. **High-Performance Networking**

    - SR-IOV for direct hardware access
    - DPDK for ultra-low latency
    - Hardware acceleration

2. **Network Segmentation**

    - Separate management and data networks
    - Isolated control plane
    - Different security zones

3. **Multi-Tenant Networks**

    - Per-tenant network isolation
    - Private networks per application
    - VLAN segmentation

4. **Legacy Application Support**

    - Apps expecting multiple NICs
    - Traditional networking models
    - Migration from VMs to containers

5. **Hybrid Networking**
    - Mix of overlay and underlay networks
    - Integration with existing infrastructure
    - Bridge to physical networks

### ❌ You probably don't need Multus if:

-   You only need basic Kubernetes networking
-   Single network interface per pod is sufficient
-   You're just getting started with Kubernetes
-   You don't have specialized networking requirements

## What You Get with Multus in k8s-local

When you enable Multus during cluster creation (after selecting Cilium or Calico):

### Thin Plugin Configuration (Recommended):

-   Lightweight Multus daemonset
-   Delegates to your primary CNI (Cilium/Calico) for eth0
-   Ready to add additional networks via NetworkAttachmentDefinition
-   Minimal resource overhead

### Thick Plugin Configuration:

-   Full-featured Multus daemonset
-   Independent network management
-   Built-in IPAM capabilities
-   More configuration options

### Common Features:

-   Automatic CRD installation (NetworkAttachmentDefinition)
-   Tolerations for control plane scheduling
-   Integration with primary CNI
-   Ready for additional network definitions

## Using Multus CNI

### 1. Verify Multus Installation

```bash
# Check Multus pods are running
kubectl get pods -n kube-system -l app=multus

# Verify Multus daemonset
kubectl get daemonset kube-multus-ds -n kube-system

# Check CRDs are installed
kubectl get crd | grep network-attachment-definitions
```

### 2. Create Network Attachment Definitions

#### Example: macvlan Network

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
  namespace: default
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "macvlan",
    "master": "eth0",
    "mode": "bridge",
    "ipam": {
      "type": "host-local",
      "subnet": "192.168.1.0/24",
      "rangeStart": "192.168.1.200",
      "rangeEnd": "192.168.1.216",
      "gateway": "192.168.1.1"
    }
  }'
```

#### Example: Bridge Network

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: bridge-conf
  namespace: default
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "bridge",
    "bridge": "mybridge",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
      "type": "host-local",
      "subnet": "10.244.0.0/16",
      "gateway": "10.244.0.1"
    }
  }'
```

#### Example: SR-IOV Network (Advanced)

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: sriov-net
  namespace: default
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "sriov",
    "vlan": 100,
    "ipam": {
      "type": "host-local",
      "subnet": "10.56.217.0/24",
      "routes": [{
        "dst": "0.0.0.0/0"
      }],
      "gateway": "10.56.217.1"
    }
  }'
```

### 3. Attach Networks to Pods

#### Single Additional Network

```yaml
apiVersion: v1
kind: Pod
metadata:
    name: multi-net-pod
    annotations:
        k8s.v1.cni.cncf.io/networks: macvlan-conf
spec:
    containers:
        - name: app
          image: nginx
          ports:
              - containerPort: 80
```

#### Multiple Additional Networks

```yaml
apiVersion: v1
kind: Pod
metadata:
    name: multi-net-pod
    annotations:
        k8s.v1.cni.cncf.io/networks: macvlan-conf, bridge-conf
spec:
    containers:
        - name: app
          image: nginx
```

#### Specify Interface Names

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-net-pod
  annotations:
    k8s.v1.cni.cncf.io/networks: '[
      { "name": "macvlan-conf", "interface": "data1" },
      { "name": "bridge-conf", "interface": "mgmt0" }
    ]'
spec:
  containers:
  - name: app
    image: nginx
```

#### Cross-Namespace Network

```yaml
apiVersion: v1
kind: Pod
metadata:
    name: multi-net-pod
    annotations:
        k8s.v1.cni.cncf.io/networks: other-namespace/macvlan-conf
spec:
    containers:
        - name: app
          image: nginx
```

### 4. Verify Pod Networking

```bash
# Check pod has multiple interfaces
kubectl exec multi-net-pod -- ip addr

# Expected output:
# 1: lo: ...
# 2: eth0@if123: ... (default Cilium/Calico interface)
# 3: net1@if124: ... (macvlan interface)
# 4: net2@if125: ... (bridge interface)

# Test connectivity on additional interface
kubectl exec multi-net-pod -- ping -I net1 192.168.1.1

# View network attachment status
kubectl get pods multi-net-pod -o jsonpath='{.metadata.annotations}'
```

## Use Cases and Examples

### Use Case 1: Separate Management and Data Networks

**Scenario**: Database pod with management access on eth0 and high-speed data access on net1

```yaml
# NetworkAttachmentDefinition for data network
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: data-network
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "macvlan",
    "master": "eth1",
    "ipam": {
      "type": "host-local",
      "subnet": "10.10.0.0/16"
    }
  }'
---
# Database pod with two networks
apiVersion: v1
kind: Pod
metadata:
  name: postgres
  annotations:
    k8s.v1.cni.cncf.io/networks: data-network
spec:
  containers:
  - name: postgres
    image: postgres:15
    env:
    - name: POSTGRES_PASSWORD
      value: "secret"
```

### Use Case 2: Multi-Tenant Isolation

**Scenario**: Different tenants on isolated networks

```yaml
# Tenant A network
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: tenant-a-net
  namespace: tenant-a
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "bridge",
    "bridge": "tenant-a-br",
    "ipam": {
      "type": "host-local",
      "subnet": "10.100.0.0/16"
    }
  }'
---
# Tenant B network (isolated)
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: tenant-b-net
  namespace: tenant-b
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "bridge",
    "bridge": "tenant-b-br",
    "ipam": {
      "type": "host-local",
      "subnet": "10.200.0.0/16"
    }
  }'
```

### Use Case 3: Legacy Application Migration

**Scenario**: Application expects specific network interface names

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
  annotations:
    k8s.v1.cni.cncf.io/networks: '[
      { "name": "mgmt-net", "interface": "eth1" },
      { "name": "data-net", "interface": "eth2" }
    ]'
spec:
  containers:
  - name: app
    image: legacy-app:v1
```

## Troubleshooting

### Multus Pods Not Running

```bash
# Check pod status
kubectl get pods -n kube-system -l app=multus

# View logs
kubectl logs -n kube-system -l app=multus --tail=50

# Check daemonset
kubectl describe daemonset kube-multus-ds -n kube-system
```

### Network Attachment Not Working

```bash
# Verify NetworkAttachmentDefinition exists
kubectl get network-attachment-definitions -A

# Check definition syntax
kubectl get network-attachment-definition macvlan-conf -o yaml

# View pod events
kubectl describe pod multi-net-pod

# Check annotations
kubectl get pod multi-net-pod -o jsonpath='{.metadata.annotations}'
```

### Pod Not Getting Additional Interfaces

```bash
# Check Multus logs for errors
kubectl logs -n kube-system -l app=multus | grep -i error

# Verify CNI plugins are installed
kubectl exec -n kube-system kube-multus-ds-xxxxx -- ls /opt/cni/bin

# Test network attachment manually
kubectl exec multi-net-pod -- ip link show
```

### IPAM Issues

```bash
# Check IP allocation in NetworkAttachmentDefinition
kubectl get net-attach-def macvlan-conf -o yaml

# Verify IP ranges don't conflict
# Check subnet, rangeStart, rangeEnd values

# View allocated IPs (if using whereabouts IPAM)
kubectl get ippools -A
```

## Best Practices

### 1. Network Naming Convention

```yaml
# Use descriptive names
data-network       # Good
storage-backend    # Good
net1              # Bad - not descriptive
```

### 2. Namespace Organization

```yaml
# Keep network definitions in same namespace as pods
# Or use cross-namespace reference
metadata:
    name: shared-network
    namespace: network-configs
```

### 3. Resource Limits

```yaml
# Set resource requests/limits for pods with multiple networks
resources:
    requests:
        memory: '1Gi'
        cpu: '500m'
    limits:
        memory: '2Gi'
        cpu: '1000m'
```

### 4. Documentation

```yaml
# Document network purpose in annotations
metadata:
    annotations:
        description: 'High-speed data plane network for database replication'
        owner: 'database-team'
```

## Learn More

### Official Resources

-   **GitHub**: https://github.com/k8snetworkplumbingwg/multus-cni
-   **Documentation**: https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs
-   **Quick Start**: https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md
-   **Spec**: https://github.com/k8snetworkplumbingwg/network-attachment-definition-client

### Tutorials

-   **Thick vs Thin**: https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/thick-plugin.md
-   **Configuration Reference**: https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/configuration.md
-   **How It Works**: https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/how-to-use.md

### Community

-   **Network Plumbing Working Group**: https://github.com/k8snetworkplumbingwg
-   **Kubernetes Slack**: #sig-network channel
-   **Issues**: https://github.com/k8snetworkplumbingwg/multus-cni/issues

## Advanced Topics

### Custom IPAM

```yaml
# Using whereabouts IPAM for dynamic allocation
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: whereabouts-net
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "macvlan",
    "master": "eth0",
    "ipam": {
      "type": "whereabouts",
      "range": "192.168.2.0/24"
    }
  }'
```

### Default Network Override

```yaml
# Use different CNI as default (advanced)
annotations:
    v1.multus-cni.io/default-network: bridge-conf
```

### Network Selection Priority

```yaml
# Control network attachment order
annotations:
  k8s.v1.cni.cncf.io/networks: '[
    { "name": "net1", "interface": "eth1" },
    { "name": "net2", "interface": "eth2" }
  ]'
```

## Next Steps

-   ✅ Install Multus: Enable during cluster creation (after selecting Cilium or Calico)
-   📝 Create NetworkAttachmentDefinitions: Define your additional networks
-   🔧 Test with simple pod: Verify multiple interfaces work
-   📊 Monitor performance: Check overhead and throughput
-   📚 Explore advanced features: SR-IOV, DPDK, custom IPAM
