# Calico CNI Guide

## Overview

Calico is a proven, open-source networking and security solution for containers, virtual machines, and bare-metal workloads. It provides simple, scalable, and secure network connectivity with advanced network policy enforcement.

## What is Calico?

Calico is a pure Layer 3 networking solution that uses standard Linux networking and routing to provide:

-   **Scalable Networking**: Efficient routing without overlay networks
-   **Network Policies**: Comprehensive security policies at Layer 3/4
-   **Flexible Deployment**: Works with various datastore backends
-   **Battle-Tested**: Used in production by thousands of organizations

## Key Features

### 1. Layer 3 Networking

-   Pure IP networking without overlays
-   Standard Linux routing protocols (BGP)
-   Efficient and scalable architecture
-   No encapsulation overhead

### 2. Network Policy Engine

-   Kubernetes NetworkPolicy support
-   Extended Calico NetworkPolicy with more features
-   Global network policies
-   Tiered policy management (Calico Enterprise)

### 3. IP Address Management (IPAM)

-   Flexible IP allocation strategies
-   Support for multiple IP pools
-   IPv4 and IPv6 support
-   Integration with cloud provider IPAM

### 4. Security Features

-   Workload isolation
-   Host endpoint protection
-   Application Layer (L7) policies (Calico Enterprise)
-   Encryption in transit (WireGuard)

### 5. Observability

-   Flow logs and metrics
-   Integration with Prometheus
-   Network policy analytics
-   Troubleshooting tools (calicoctl)

## When to Use Calico

✅ **Choose Calico if you need:**

-   Battle-tested, production-proven networking
-   Advanced network policy management
-   Multi-tenancy with strong isolation
-   Hybrid cloud or multi-cloud deployments
-   Integration with existing networking infrastructure
-   Standard Linux networking (familiar to ops teams)

❌ **Consider alternatives if:**

-   You need Layer 7 HTTP/gRPC policy enforcement (use Cilium)
-   You want eBPF-based performance optimizations
-   You need built-in service mesh features

## What You Get with Calico in k8s-local

When you select Calico during cluster creation, the script automatically:

### For Kind Clusters:

-   Installs Tigera Operator (recommended deployment method)
-   Configures Calico with standard settings
-   Sets up automatic IP allocation
-   Enables Kubernetes provider auto-detection

### For Talos Clusters:

-   Applies Talos-specific CNI configuration (`installation.cni.type=Calico`)
-   Configures namespace labels for Talos pod security
-   Optimizes for Talos Linux environment
-   Ensures compatibility with Talos DNS forwarding

### Common Configuration:

-   Tigera Operator for lifecycle management
-   Default IP pool configuration
-   Standard IPAM settings
-   NetworkPolicy support enabled

## Using Calico

### Check Calico Status

```bash
# View Calico pods
kubectl get pods -n calico-system

# Check operator status
kubectl get pods -n tigera-operator

# View Calico installation
kubectl get installation default -o yaml
```

### Install calicoctl (Recommended)

```bash
# macOS
brew install calicoctl

# Linux
curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/

# Or use as kubectl plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calicoctl.yaml
alias calicoctl="kubectl exec -i -n kube-system calicoctl -- /calicoctl"
```

### View Network Configuration

```bash
# Check node status
calicoctl get nodes

# View IP pools
calicoctl get ippool -o wide

# Check BGP peer status (if using BGP)
calicoctl node status
```

### Network Policies

#### Basic Kubernetes NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: api-allow
    namespace: default
spec:
    podSelector:
        matchLabels:
            app: api
    policyTypes:
        - Ingress
        - Egress
    ingress:
        - from:
              - podSelector:
                    matchLabels:
                        app: web
          ports:
              - protocol: TCP
                port: 8080
    egress:
        - to:
              - podSelector:
                    matchLabels:
                        app: database
          ports:
              - protocol: TCP
                port: 5432
```

#### Advanced Calico NetworkPolicy

```yaml
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
    name: database-policy
    namespace: production
spec:
    selector: app == 'postgres'
    types:
        - Ingress
        - Egress
    ingress:
        - action: Allow
          protocol: TCP
          source:
              selector: tier == 'backend'
          destination:
              ports:
                  - 5432
        - action: Log
          protocol: TCP
          source:
              notSelector: tier == 'backend'
    egress:
        - action: Allow
```

#### Global Network Policy (Cluster-wide)

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
    name: deny-egress-external
spec:
    selector: has(restricted)
    types:
        - Egress
    egress:
        # Allow DNS
        - action: Allow
          protocol: UDP
          destination:
              ports:
                  - 53
        # Allow internal cluster traffic
        - action: Allow
          destination:
              nets:
                  - 10.0.0.0/8
        # Deny all other egress
        - action: Deny
```

### Troubleshooting Tools

```bash
# Check BGP routes
calicoctl get bgpconfig

# View workload endpoints
calicoctl get workloadendpoints --all-namespaces

# Check policy on specific pod
calicoctl get networkpolicy --namespace=<ns> -o yaml

# Debug connectivity issues
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
```

## Security Best Practices

### 1. Default Deny Policies

```yaml
# Deny all ingress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: default-deny-ingress
spec:
    podSelector: {}
    policyTypes:
        - Ingress
---
# Deny all egress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: default-deny-egress
spec:
    podSelector: {}
    policyTypes:
        - Egress
```

### 2. Allow DNS

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: allow-dns
spec:
    podSelector: {}
    policyTypes:
        - Egress
    egress:
        - to:
              - namespaceSelector:
                    matchLabels:
                        kubernetes.io/metadata.name: kube-system
              - podSelector:
                    matchLabels:
                        k8s-app: kube-dns
          ports:
              - protocol: UDP
                port: 53
```

### 3. Namespace Isolation

```yaml
# Only allow traffic within namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: namespace-isolation
    namespace: production
spec:
    podSelector: {}
    policyTypes:
        - Ingress
        - Egress
    ingress:
        - from:
              - podSelector: {}
    egress:
        - to:
              - podSelector: {}
```

## Performance Optimization

### 1. IP Pool Configuration

```bash
# Create custom IP pool with specific block size
calicoctl create -f - <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: custom-pool
spec:
  cidr: 192.168.0.0/16
  blockSize: 26
  ipipMode: Never
  natOutgoing: true
EOF
```

### 2. Felix Configuration

```bash
# Tune Felix parameters for performance
calicoctl patch felixconfiguration default --patch '
{
  "spec": {
    "iptablesRefreshInterval": "60s",
    "routeRefreshInterval": "60s",
    "iptablesPostWriteCheckIntervalSecs": 5
  }
}'
```

## Monitoring and Observability

### Prometheus Integration

```yaml
# ServiceMonitor for Calico metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
    name: calico-metrics
    namespace: calico-system
spec:
    selector:
        matchLabels:
            k8s-app: calico-node
    endpoints:
        - port: metrics
          interval: 30s
```

### Flow Logs

Enable flow logging for network traffic analysis:

```bash
# Enable flow logs
calicoctl patch felixconfiguration default --patch '
{
  "spec": {
    "flowLogsEnableHostEndpoint": true,
    "flowLogsFileEnabled": true
  }
}'
```

## Troubleshooting

### Pods Not Getting IP Addresses

```bash
# Check Calico node status
kubectl get pods -n calico-system -l k8s-app=calico-node

# View Calico node logs
kubectl logs -n calico-system -l k8s-app=calico-node --tail=50

# Check IP pool allocation
calicoctl get ippool -o wide
calicoctl ipam show
```

### Network Policy Not Working

```bash
# Verify policy syntax
calicoctl get networkpolicy --namespace=<ns> -o yaml

# Check policy order and precedence
calicoctl get globalnetworkpolicy

# Test connectivity
kubectl run test-pod --image=busybox --restart=Never -- sh -c "sleep 3600"
kubectl exec test-pod -- wget -O- http://<target-service>
```

### DNS Resolution Issues

```bash
# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check DNS policy allows CoreDNS access
calicoctl get networkpolicy --all-namespaces | grep dns
```

### Node Communication Issues

```bash
# Check node readiness
kubectl get nodes

# View Calico node status
calicoctl node status

# Check routes
calicoctl get bgpconfig default -o yaml
```

## Learn More

### Official Resources

-   **Website**: https://www.tigera.io/project-calico/
-   **Documentation**: https://docs.tigera.io/calico/latest/about/
-   **GitHub**: https://github.com/projectcalico/calico
-   **Getting Started**: https://docs.tigera.io/calico/latest/getting-started/kubernetes/

### Tutorials

-   **Network Policy Tutorial**: https://docs.tigera.io/calico/latest/network-policy/get-started/
-   **calicoctl Guide**: https://docs.tigera.io/calico/latest/reference/calicoctl/
-   **BGP Configuration**: https://docs.tigera.io/calico/latest/networking/bgp
-   **Security Best Practices**: https://docs.tigera.io/calico/latest/network-policy/recommendations

### Community

-   **Slack**: https://calicousers.slack.com/
-   **Community Meetings**: https://www.projectcalico.org/community/
-   **Blog**: https://www.tigera.io/blog/

## Calico Enterprise

For production environments, consider **Calico Enterprise** which adds:

-   **Tiered Network Policies**: Hierarchical policy management
-   **DNS Policy**: Policy based on DNS names
-   **Deep Packet Inspection**: L7 visibility and policies
-   **Compliance Reporting**: Audit and compliance features
-   **Web UI**: Graphical policy management
-   **24/7 Support**: Enterprise-grade support

Learn more: https://www.tigera.io/tigera-products/calico-enterprise/

## Configuration Reference

The k8s-local script uses the following Helm values for Calico:

### Common Values (All Providers)

```yaml
# Installed via Tigera Operator
installation:
    enabled: true
    kubernetesProvider: '' # Auto-detect
```

### Talos-Specific Values

```yaml
installation:
    cni:
        type: Calico # Explicit CNI type for Talos
```

## Next Steps

-   ✅ Install Calico: Follow cluster creation prompts and select `calico`
-   📋 Install calicoctl: Get the CLI tool for advanced management
-   🔒 Define policies: Start with default-deny and build up
-   📊 Enable monitoring: Integrate with Prometheus for metrics
-   📚 Read policy guides: Master network policy best practices
