# Cilium CNI Guide

## Overview

Cilium is a modern, eBPF-based Container Network Interface (CNI) plugin that provides high-performance networking, security, and observability for Kubernetes clusters.

## What is Cilium?

Cilium leverages eBPF (extended Berkeley Packet Filter), a Linux kernel technology that allows running sandboxed programs in the kernel without changing kernel source code. This enables:

-   **High Performance**: Direct packet processing in the kernel
-   **Deep Observability**: Network visibility at Layer 3/4 and Layer 7
-   **Advanced Security**: Identity-based security policies
-   **Service Mesh**: Efficient service-to-service communication

## Key Features

### 1. eBPF-Powered Networking

-   Direct kernel-level packet processing
-   Lower latency and higher throughput than traditional iptables
-   Minimal CPU overhead

### 2. Kube-Proxy Replacement

-   Replaces kube-proxy with eBPF-based load balancing
-   More efficient service routing
-   Better performance for service mesh workloads

### 3. Network Policies

-   Layer 3/4 network policies (IP/port)
-   Layer 7 network policies (HTTP, gRPC, Kafka)
-   DNS-aware policies

### 4. Observability

-   Flow logs and metrics
-   Service dependency maps
-   Network troubleshooting tools

### 5. Multi-Cluster & Service Mesh

-   Cluster mesh for multi-cluster connectivity
-   Native service mesh capabilities
-   Mutual TLS (mTLS) support

## When to Use Cilium

✅ **Choose Cilium if you need:**

-   High-performance networking with low overhead
-   Advanced observability and monitoring
-   Layer 7 network policies (HTTP/gRPC)
-   Modern eBPF-based technology
-   Service mesh capabilities without additional components
-   Deep packet inspection and filtering

❌ **Consider alternatives if:**

-   You need maximum compatibility with older kernels (< 4.9)
-   You prefer traditional, well-established tools
-   Your team is not familiar with eBPF concepts

## What You Get with Cilium in k8s-local

When you select Cilium during cluster creation, the script automatically:

### For Kind Clusters:

-   Configures Cilium with in-cluster API server discovery
-   Enables Docker-optimized image pulling
-   Sets up tolerations for scheduling on not-ready nodes
-   Configures kube-proxy replacement

### For Talos Clusters:

-   Applies Talos-specific security contexts
-   Configures cgroup settings for Talos Linux
-   Enables legacy routing for DNS compatibility (`bpf.hostLegacyRouting=true`)
-   Sets Talos API server endpoint (localhost:7445)
-   Optimizes for Docker-based Talos nodes

### Common Configuration:

-   Single operator replica (suitable for local dev)
-   Kubernetes IPAM mode
-   Full kube-proxy replacement enabled
-   Tolerations for control plane scheduling

## Using Cilium

### Check Cilium Status

```bash
# View Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Execute cilium status in agent pod
kubectl -n kube-system exec ds/cilium -- cilium status

# View Cilium configuration
kubectl -n kube-system exec ds/cilium -- cilium config view
```

### Run Connectivity Tests

```bash
# Install Cilium CLI (optional but recommended)
brew install cilium-cli

# Run connectivity test
cilium connectivity test
```

### Monitor Network Traffic

```bash
# Watch network flows
kubectl -n kube-system exec ds/cilium -- cilium monitor

# Filter by pod
kubectl -n kube-system exec ds/cilium -- cilium monitor --related-to <pod-name>

# View service endpoints
kubectl -n kube-system exec ds/cilium -- cilium service list
```

### Network Policies

Create Layer 7 HTTP policy:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
    name: allow-specific-api
spec:
    endpointSelector:
        matchLabels:
            app: backend
    ingress:
        - fromEndpoints:
              - matchLabels:
                    app: frontend
          toPorts:
              - ports:
                    - port: '8080'
                      protocol: TCP
                rules:
                    http:
                        - method: 'GET'
                          path: '/api/.*'
```

### Hubble Observability

Enable Hubble for network observability:

```bash
# Install Hubble CLI
brew install hubble

# Port-forward Hubble Relay
kubectl port-forward -n kube-system deployment/cilium-operator 4245:4245

# View flows
hubble observe

# Service dependency graph
hubble observe --from-pod <namespace>/<pod> --to-service <service>
```

## Performance Tips

1. **Enable eBPF Host Routing**: Already enabled in k8s-local for Talos
2. **Use Direct Routing**: For better performance in supported environments
3. **Enable BPF NodePort**: More efficient than iptables-based NodePort
4. **Tune Buffer Sizes**: Adjust for high-throughput workloads

## Troubleshooting

### Pods Not Starting After CNI Installation

```bash
# Check Cilium agent logs
kubectl -n kube-system logs -l k8s-app=cilium --tail=50

# Check Cilium operator logs
kubectl -n kube-system logs deployment/cilium-operator --tail=50

# Verify Cilium health
kubectl -n kube-system exec ds/cilium -- cilium-health status
```

### DNS Issues

```bash
# Verify DNS is working
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check if bpf.hostLegacyRouting is enabled (Talos)
kubectl -n kube-system exec ds/cilium -- cilium config view | grep hostLegacyRouting
```

### Network Policies Not Working

```bash
# Verify policy is loaded
kubectl -n kube-system exec ds/cilium -- cilium policy get

# Check policy enforcement
kubectl -n kube-system exec ds/cilium -- cilium endpoint list
```

## Learn More

### Official Resources

-   **Website**: https://cilium.io/
-   **Documentation**: https://docs.cilium.io/
-   **GitHub**: https://github.com/cilium/cilium
-   **Getting Started**: https://docs.cilium.io/en/stable/gettingstarted/

### Tutorials

-   **Cilium Network Policies**: https://docs.cilium.io/en/stable/security/policy/
-   **Hubble Observability**: https://docs.cilium.io/en/stable/observability/
-   **Service Mesh**: https://docs.cilium.io/en/stable/network/servicemesh/
-   **Multi-Cluster**: https://docs.cilium.io/en/stable/network/clustermesh/

### Community

-   **Slack**: https://cilium.io/slack
-   **Community Meetings**: https://github.com/cilium/cilium#community
-   **Blog**: https://cilium.io/blog/

## Configuration Reference

The k8s-local script uses the following Helm values for Cilium:

### Common Values (All Providers)

```yaml
operator:
    replicas: 1
    tolerations:
        - operator: Exists

ipam:
    mode: kubernetes

kubeProxyReplacement: true

tolerations:
    - operator: Exists

image:
    pullPolicy: IfNotPresent
```

### Talos-Specific Values

```yaml
k8sServiceHost: localhost
k8sServicePort: 7445

securityContext:
    capabilities:
        ciliumAgent:
            - CHOWN
            - KILL
            - NET_ADMIN
            - NET_RAW
            - IPC_LOCK
            - SYS_ADMIN
            - SYS_RESOURCE
            - DAC_OVERRIDE
            - FOWNER
            - SETGID
            - SETUID
        cleanCiliumState:
            - NET_ADMIN
            - SYS_ADMIN
            - SYS_RESOURCE

cgroup:
    autoMount:
        enabled: false
    hostRoot: /sys/fs/cgroup

bpf:
    hostLegacyRouting: true
```

## Next Steps

-   ✅ Install Cilium: Follow cluster creation prompts and select `cilium`
-   📊 Explore observability: Install Hubble for network visibility
-   🔒 Secure workloads: Implement Layer 7 network policies
-   🔗 Enable multi-cluster: Set up Cluster Mesh for cross-cluster communication
-   📚 Read advanced guides: Check official Cilium documentation for advanced features
