# Fish completion script for k8s-local.sh / kl.sh / create-cluster.sh

# Main commands
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "create" -d "Create a new Kubernetes cluster"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "delete" -d "Delete an existing cluster"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "list" -d "List all clusters"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "info" -d "Show cluster information"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "config" -d "Show cluster configuration"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "start" -d "Start a stopped cluster"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "stop" -d "Stop a running cluster"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "help" -d "Show help message"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "helm" -d "Manage Helm installations"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "apps" -d "Manage ArgoCD applications"
complete -c k8s-local.sh -f -n "__fish_use_subcommand" -a "install" -d "Install components or apps"

# helm subcommands
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from helm" -a "list" -d "List available Helm components"

# apps subcommands
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from apps" -a "list" -d "List available ArgoCD apps"

# install subcommands
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and not __fish_seen_subcommand_from helm apps" -a "helm" -d "Install Helm component"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and not __fish_seen_subcommand_from helm apps" -a "apps" -d "Install ArgoCD app"

# Helm components (after: install helm ...)
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "argocd" -d "ArgoCD GitOps controller"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "cert-manager" -d "Certificate management"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "cnpg" -d "CloudNativePG operator"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "crossplane" -d "Cloud native control plane"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "falco" -d "Runtime security"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "hashicorp-vault" -d "Secrets management"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "kube-prometheus-stack" -d "Prometheus monitoring"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "kubeview" -d "Kubernetes cluster visualizer"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "metallb" -d "Load balancer for bare metal"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "minio" -d "S3-compatible object storage"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "mongodb-operator" -d "MongoDB operator"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "nats" -d "NATS messaging system"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "nfs" -d "NFS provisioner"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "nginx-ingress" -d "NGINX ingress controller"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "opencost" -d "Cost monitoring"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "pgadmin" -d "PostgreSQL admin UI"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "redis-stack" -d "Redis Stack server"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "rook-ceph-operator" -d "Rook Ceph operator"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from helm" -a "trivy" -d "Security scanner"

# ArgoCD apps (after: install apps ...)
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "nyancat" -d "Sample Nyancat demo"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "prometheus" -d "Kube Prometheus Stack"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "cert-manager" -d "Cert Manager application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "cnpg-cluster" -d "CNPG cluster instance"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "crossplane" -d "Crossplane application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "falco" -d "Falco security"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "hashicorp-vault" -d "Vault application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "kubeview" -d "KubeView application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "metallb" -d "MetalLB application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "minio" -d "MinIO application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "mongodb" -d "MongoDB instance"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "mongodb-operator" -d "MongoDB operator app"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "nats" -d "NATS application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "nfs" -d "NFS provisioner app"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "opencost" -d "OpenCost application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "pg-ui" -d "PostgreSQL UI"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "pgadmin" -d "PgAdmin application"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "redis-stack" -d "Redis Stack app"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "rook-ceph-cluster" -d "Rook Ceph cluster"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "rook-ceph-operator" -d "Rook Ceph operator app"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "trivy" -d "Trivy scanner app"
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install; and __fish_seen_subcommand_from apps" -a "coredns" -d "CoreDNS application"

# --dry-run flag (after install command)
complete -c k8s-local.sh -f -n "__fish_seen_subcommand_from install" -l "dry-run" -d "Show what would be installed"

# Also register for kl.sh and create-cluster.sh
complete -c kl.sh -w k8s-local.sh
complete -c create-cluster.sh -w k8s-local.sh
complete -c k8s-local -w k8s-local.sh
complete -c kl -w k8s-local.sh
complete -c create-cluster -w k8s-local.sh
