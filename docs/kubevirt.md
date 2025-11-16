# KubeVirt - Virtual Machine Management for Kubernetes

KubeVirt is a Kubernetes add-on that enables you to run and manage virtual machines (VMs) alongside containers using native Kubernetes tools and APIs.

## Overview

KubeVirt extends Kubernetes with additional virtualization resource types (via custom resources) and allows you to:

-   Run traditional VM workloads on Kubernetes
-   Use standard Kubernetes tools (kubectl, etc.) to manage VMs
-   Leverage Kubernetes features like scheduling, networking, and storage for VMs
-   Gradually migrate VM-based applications to containers

## Installation

### Prerequisites

#### For Kind Clusters

Kind clusters work out-of-the-box with KubeVirt using software emulation mode.

```bash
# Install KubeVirt on a kind cluster
./kl.sh install apps kubevirt
```

#### For Talos Clusters

Talos clusters require a storage provider for VM persistent volumes.

**Install a storage provider first:**

```bash
# Option 1: OpenEBS Local Path Provisioner (simple, local storage)
./kl.sh install helm localpathprovisioner

# Option 2: Rook Ceph (distributed storage, recommended for production)
./kl.sh install apps rookcephoperator,rookcephcluster

# Option 3: NFS (network storage)
./kl.sh install apps nfs
```

**Set a default StorageClass** (if not already set):

```bash
# Check current storage classes
kubectl get storageclass

# Set as default (replace <name> with your storage class)
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Then install KubeVirt:**

```bash
./kl.sh install apps kubevirt
```

## Verification

After installation, verify KubeVirt is running:

```bash
# Check KubeVirt phase (should be "Deployed")
kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}"

# Check all KubeVirt components
kubectl get all -n kubevirt

# Expected components:
# - virt-operator (deployment)
# - virt-api (deployment)
# - virt-controller (deployment)
# - virt-handler (daemonset)
```

## Installing virtctl CLI

`virtctl` is the command-line tool for managing KubeVirt VMs.

### Option 1: Direct Download

```bash
VERSION=$(kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.observedKubeVirtVersion}")
ARCH=$(uname -s | tr A-Z a-z)-$(uname -m | sed 's/x86_64/amd64/')
curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-${ARCH}
chmod +x virtctl
sudo mv virtctl /usr/local/bin/
```

### Option 2: Kubectl Plugin (via Krew)

```bash
# Install krew first if not already installed: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
kubectl krew install virt

# Then use as kubectl plugin
kubectl virt --help
```

## Quick Start - Creating Your First VM

### 1. Create a Simple Test VM

```bash
# Apply a test VM manifest
kubectl apply -f https://kubevirt.io/labs/manifests/vm.yaml

# Check VM status
kubectl get vms
kubectl get vmis  # VM instances
```

### 2. Start and Access the VM

```bash
# Start the VM
virtctl start testvm

# Wait for the VM to be running
kubectl wait vmi testvm --for=condition=Ready --timeout=180s

# Connect to the VM console
virtctl console testvm

# SSH into the VM (if SSH is configured)
virtctl ssh cirros@testvm
```

### 3. Manage the VM

```bash
# Stop the VM
virtctl stop testvm

# Restart the VM
virtctl restart testvm

# Delete the VM
kubectl delete vm testvm
```

## Creating VMs from Disk Images

### Using a PersistentVolumeClaim

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
    name: ubuntu-vm
spec:
    running: false
    template:
        metadata:
            labels:
                kubevirt.io/vm: ubuntu-vm
        spec:
            domain:
                devices:
                    disks:
                        - name: containerdisk
                          disk:
                              bus: virtio
                        - name: cloudinitdisk
                          disk:
                              bus: virtio
                resources:
                    requests:
                        memory: 1024M
            volumes:
                - name: containerdisk
                  containerDisk:
                      image: quay.io/containerdisks/ubuntu:22.04
                - name: cloudinitdisk
                  cloudInitNoCloud:
                      userData: |
                          #cloud-config
                          password: ubuntu
                          chpasswd: { expire: False }
```

### Using Containerized Disks

ContainerDisks are VM images stored as container images:

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
    name: fedora-vm
spec:
    running: true
    template:
        metadata:
            labels:
                kubevirt.io/vm: fedora-vm
        spec:
            domain:
                devices:
                    disks:
                        - name: containerdisk
                          disk:
                              bus: virtio
                resources:
                    requests:
                        memory: 2048M
            volumes:
                - name: containerdisk
                  containerDisk:
                      image: quay.io/containerdisks/fedora:latest
```

## Networking

### Default Pod Network

By default, VMs use the Kubernetes pod network:

```yaml
spec:
    template:
        spec:
            domain:
                devices:
                    interfaces:
                        - name: default
                          masquerade: {}
            networks:
                - name: default
                  pod: {}
```

### Bridge Network

For direct network access (requires Multus CNI):

```yaml
spec:
    template:
        spec:
            domain:
                devices:
                    interfaces:
                        - name: default
                          bridge: {}
            networks:
                - name: default
                  multus:
                      networkName: bridge-network
```

## Storage

### Using PVCs for VM Disks

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: vm-disk
spec:
    accessModes:
        - ReadWriteOnce
    resources:
        requests:
            storage: 10Gi
    storageClassName: local-path # or rook-ceph-block, etc.
---
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
    name: vm-with-pvc
spec:
    running: true
    template:
        spec:
            domain:
                devices:
                    disks:
                        - name: datadisk
                          disk:
                              bus: virtio
                resources:
                    requests:
                        memory: 1024M
            volumes:
                - name: datadisk
                  persistentVolumeClaim:
                      claimName: vm-disk
```

## Advanced Features

### Live Migration

Move running VMs between nodes without downtime:

```bash
# Migrate a VM
virtctl migrate ubuntu-vm

# Check migration status
kubectl get virtualmachineinstancemigration
```

### Snapshots

Create VM snapshots (requires CSI snapshot support):

```yaml
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineSnapshot
metadata:
    name: my-vm-snapshot
spec:
    source:
        apiGroup: kubevirt.io
        kind: VirtualMachine
        name: my-vm
```

### GPU Passthrough

Pass GPU devices to VMs (requires host GPU):

```yaml
spec:
    template:
        spec:
            domain:
                devices:
                    gpus:
                        - name: gpu1
                          deviceName: nvidia.com/GV100GL_Tesla_V100
```

## Monitoring

### Check VM Resources

```bash
# List all VMs
kubectl get vms -A

# Get VM details
kubectl describe vm <vm-name>

# Get VM instance details
kubectl get vmi <vm-name> -o yaml

# Check VM logs
kubectl logs -n kubevirt -l kubevirt.io=virt-launcher
```

### Metrics

KubeVirt exposes Prometheus metrics:

```bash
# Port-forward to virt-api metrics
kubectl port-forward -n kubevirt service/virt-api 8443:443

# Access metrics
curl -k https://localhost:8443/metrics
```

## Troubleshooting

### VM Won't Start

```bash
# Check VM events
kubectl describe vm <vm-name>

# Check VMI events (instance)
kubectl describe vmi <vm-name>

# Check virt-launcher pod logs
kubectl logs -n kubevirt $(kubectl get pods -n kubevirt -l kubevirt.io/vm=<vm-name> -o name)
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc

# Check StorageClass
kubectl get storageclass

# Verify PV is bound
kubectl get pv
```

### Network Issues

```bash
# Check VM network config
kubectl get vmi <vm-name> -o yaml | grep -A 10 networks

# Check virt-handler logs
kubectl logs -n kubevirt -l kubevirt.io=virt-handler
```

## Common VM Operations

```bash
# Start VM
virtctl start <vm-name>

# Stop VM (graceful)
virtctl stop <vm-name>

# Force stop VM
virtctl stop <vm-name> --force

# Restart VM
virtctl restart <vm-name>

# Pause VM
virtctl pause vm <vm-name>

# Unpause VM
virtctl unpause vm <vm-name>

# Access VM console
virtctl console <vm-name>

# VNC access
virtctl vnc <vm-name>

# Port forwarding to VM
virtctl port-forward vm/<vm-name> 8080:80
```

## Best Practices

1. **Resource Limits**: Always set memory and CPU limits for VMs
2. **Storage**: Use appropriate storage classes based on your needs:
    - `local-path`: Simple, local storage (development)
    - `rook-ceph-block`: Distributed, replicated storage (production)
3. **Networking**: Use pod network for simple setups, Multus for advanced networking
4. **Monitoring**: Enable metrics collection and monitoring
5. **Backups**: Implement regular VM snapshot and backup strategies
6. **Security**: Use pod security policies and network policies
7. **Updates**: Keep KubeVirt updated to the latest stable version

## Documentation and Resources

-   **Official Documentation**: https://kubevirt.io/user-guide/
-   **API Reference**: https://kubevirt.io/api-reference/
-   **Labs and Tutorials**: https://kubevirt.io/labs/
-   **Kind Quickstart**: https://kubevirt.io/quickstart_kind/
-   **Community**:
    -   GitHub: https://github.com/kubevirt/kubevirt
    -   Slack: https://kubernetes.slack.com/archives/C8ED7RKFE
    -   Mailing List: https://groups.google.com/forum/#!forum/kubevirt-dev

## Example VM Configurations

### Minimal CirrOS VM

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
    name: cirros-vm
spec:
    running: true
    template:
        metadata:
            labels:
                kubevirt.io/vm: cirros-vm
        spec:
            domain:
                devices:
                    disks:
                        - name: containerdisk
                          disk:
                              bus: virtio
                resources:
                    requests:
                        memory: 128M
            volumes:
                - name: containerdisk
                  containerDisk:
                      image: quay.io/kubevirt/cirros-container-disk-demo
```

### Ubuntu VM with Cloud-Init

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
    name: ubuntu-cloudinit
spec:
    running: false
    template:
        metadata:
            labels:
                kubevirt.io/vm: ubuntu-cloudinit
        spec:
            domain:
                devices:
                    disks:
                        - name: containerdisk
                          disk:
                              bus: virtio
                        - name: cloudinitdisk
                          disk:
                              bus: virtio
                    interfaces:
                        - name: default
                          masquerade: {}
                resources:
                    requests:
                        memory: 2048M
                        cpu: 2
            networks:
                - name: default
                  pod: {}
            volumes:
                - name: containerdisk
                  containerDisk:
                      image: quay.io/containerdisks/ubuntu:22.04
                - name: cloudinitdisk
                  cloudInitNoCloud:
                      userData: |
                          #cloud-config
                          hostname: ubuntu-vm
                          user: ubuntu
                          password: ubuntu
                          chpasswd: { expire: False }
                          ssh_pwauth: True
                          packages:
                            - qemu-guest-agent
                          runcmd:
                            - systemctl enable qemu-guest-agent
                            - systemctl start qemu-guest-agent
```

## Uninstalling KubeVirt

To remove KubeVirt from your cluster:

```bash
# Get the version
VERSION=$(kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.observedKubeVirtVersion}")

# Delete the KubeVirt CR
kubectl delete kubevirt kubevirt -n kubevirt

# Wait for all KubeVirt resources to be deleted
kubectl wait kubevirt kubevirt -n kubevirt --for=delete --timeout=180s

# Delete the KubeVirt operator
kubectl delete -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml"

# Delete the namespace
kubectl delete namespace kubevirt
```
