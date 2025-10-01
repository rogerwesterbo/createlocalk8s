#!/usr/bin/env zsh
# Zsh completion script for k8s-local.sh / kl.sh / create-cluster.sh

_k8s_local_zsh() {
    local line state

    # Main commands
    local -a commands
    commands=(
        'create:Create a new Kubernetes cluster'
        'delete:Delete an existing cluster'
        'list:List all clusters'
        'info:Show cluster information'
        'config:Show cluster configuration'
        'start:Start a stopped cluster'
        'stop:Stop a running cluster'
        'help:Show help message'
        'helm:Manage Helm installations'
        'apps:Manage ArgoCD applications'
        'install:Install Helm components or ArgoCD apps'
    )

    # Helm components
    local -a helm_components
    helm_components=(
        'argocd:ArgoCD GitOps controller'
        'cert-manager:Certificate management'
        'cnpg:CloudNativePG operator'
        'crossplane:Cloud native control plane'
        'falco:Runtime security'
        'hashicorp-vault:Secrets management'
        'kube-prometheus-stack:Prometheus monitoring'
        'kubeview:Kubernetes cluster visualizer'
        'metallb:Load balancer for bare metal'
        'minio:S3-compatible object storage'
        'mongodb-operator:MongoDB operator'
        'nats:NATS messaging system'
        'nfs:NFS provisioner'
        'nginx-ingress:NGINX ingress controller'
        'opencost:Cost monitoring'
        'pgadmin:PostgreSQL admin UI'
        'redis-stack:Redis Stack server'
        'rook-ceph-operator:Rook Ceph operator'
        'trivy:Security scanner'
    )

    # ArgoCD apps
    local -a argo_apps
    argo_apps=(
        'nyancat:Sample Nyancat demo'
        'prometheus:Kube Prometheus Stack'
        'cert-manager:Cert Manager application'
        'cnpg-cluster:CNPG cluster instance'
        'crossplane:Crossplane application'
        'falco:Falco security'
        'hashicorp-vault:Vault application'
        'kubeview:KubeView application'
        'metallb:MetalLB application'
        'minio:MinIO application'
        'mongodb:MongoDB instance'
        'mongodb-operator:MongoDB operator app'
        'nats:NATS application'
        'nfs:NFS provisioner app'
        'opencost:OpenCost application'
        'pg-ui:PostgreSQL UI'
        'pgadmin:PgAdmin application'
        'redis-stack:Redis Stack app'
        'rook-ceph-cluster:Rook Ceph cluster'
        'rook-ceph-operator:Rook Ceph operator app'
        'trivy:Trivy scanner app'
        'coredns:CoreDNS application'
    )

    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '3: :->item' \
        '4: :->flag' \
        && return 0

    case $state in
        command)
            _describe -t commands 'k8s-local commands' commands
            ;;
        subcommand)
            case $line[1] in
                helm)
                    _values 'helm commands' 'list[List available Helm components]'
                    ;;
                apps)
                    _values 'apps commands' 'list[List available ArgoCD apps]'
                    ;;
                install)
                    _values 'install types' 'helm[Install Helm component]' 'apps[Install ArgoCD app]'
                    ;;
            esac
            ;;
        item)
            case $line[1] in
                install)
                    case $line[2] in
                        helm)
                            _describe -t helm_components 'Helm components' helm_components
                            ;;
                        apps)
                            _describe -t argo_apps 'ArgoCD apps' argo_apps
                            ;;
                    esac
                    ;;
            esac
            ;;
        flag)
            case $line[1] in
                install)
                    _values 'flags' '--dry-run[Show what would be installed]'
                    ;;
            esac
            ;;
    esac
}

# Register completion for all script names
compdef _k8s_local_zsh k8s-local.sh
compdef _k8s_local_zsh kl.sh
compdef _k8s_local_zsh create-cluster.sh
compdef _k8s_local_zsh k8s-local
compdef _k8s_local_zsh kl
compdef _k8s_local_zsh create-cluster
