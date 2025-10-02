#!/usr/bin/env zsh
# Zsh completion script for k8s-local.sh / kl.sh / create-cluster.sh

_k8s_local_zsh() {
    local -a commands helm_components argo_apps
    local line state
    local script="${words[1]}"

    # --- Dynamic command extraction ---
    # Tries: <script> help  (adjust if your script uses --help)
    local help_out
    help_out="$($script help 2>/dev/null)"
    if [[ -z "$help_out" ]]; then
        help_out="$($script --help 2>/dev/null)"
    fi

    if [[ -n "$help_out" ]]; then
        # Extract lines under a "Commands:" header until blank line
        local cmd_block
        cmd_block="$(echo "$help_out" | sed -n '/^[[:space:]]*Commands[:]/,/^[[:space:]]*$/p')"
        # Transform "name - Description" -> "name:Description"
        commands=(${(f)"$(echo "$cmd_block" | sed -E 's/^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]+-[[:space:]]+(.+)/\1:\2/' | grep ':' )"})
    fi

    # Fallback static list if parsing produced nothing
    if (( ${#commands} == 0 )); then
        commands=(
            'create:Create a new Kubernetes cluster'
            'delete:Delete an existing cluster'
            'list:List all clusters'
            'info:Show cluster information'
            'config:Show cluster configuration'
            'start:Start a stopped cluster'
            'stop:Stop a running cluster'
            'help:Show help message'
            'helm:Manage Helm components'
            'apps:Manage ArgoCD applications'
            'install:Install Helm component or ArgoCD app'
        )
    fi

    # --- Dynamic Helm components ---
    # Expect something like a newline list or table; we take first column tokens
    local helm_out
    helm_out="$($script helm list 2>/dev/null)"
    if [[ -n "$helm_out" ]]; then
        # Remove header lines commonly containing NAME or similar
        helm_components=(${(f)"$(echo "$helm_out" | awk 'NR==1 && tolower($0) ~ /name/ {next} {print $1}' | sed -E '/^$/d')"})
        helm_components=(${helm_components:#(NAME|NAME:)*})
        # Map to "name:Helm component"
        for i in {1..${#helm_components[@]}}; do
            helm_components[$i]="${helm_components[$i]}:Helm component"
        done
    fi
    # Fallback static list
    if (( ${#helm_components} == 0 )); then
        helm_components=(
            'argocd:ArgoCD'
            'cert-manager:cert-manager'
            'cnpg:CloudNativePG operator'
            'crossplane:Crossplane'
            'falco:Falco'
            'hashicorp-vault:Vault'
            'kube-prometheus-stack:Prometheus stack'
            'kubeview:KubeView'
            'metallb:MetalLB'
            'minio:MinIO'
            'mongodb-operator:MongoDB operator'
            'nats:NATS'
            'nfs:NFS provisioner'
            'nginx-ingress:NGINX ingress'
            'opencost:OpenCost'
            'pgadmin:PgAdmin'
            'redis-stack:Redis Stack'
            'rook-ceph-operator:Rook Ceph operator'
            'trivy:Trivy'
        )
    fi

    # --- Dynamic Argo apps ---
    local apps_out
    apps_out="$($script apps list 2>/dev/null)"
    if [[ -n "$apps_out" ]]; then
        argo_apps=(${(f)"$(echo "$apps_out" | awk '{print $1}' | sed -E '/^(NAME|Name|#|$)/d')"})
        for i in {1..${#argo_apps[@]}}; do
            argo_apps[$i]="${argo_apps[$i]}:ArgoCD app"
        done
    fi
    # Fallback static list
    if (( ${#argo_apps} == 0 )); then
        argo_apps=(
            'nyancat:Nyancat demo'
            'prometheus:Kube Prometheus Stack'
            'cert-manager:Cert Manager app'
            'cnpg-cluster:CNPG cluster'
            'crossplane:Crossplane app'
            'falco:Falco'
            'hashicorp-vault:Vault'
            'kubeview:KubeView'
            'metallb:MetalLB'
            'minio:MinIO'
            'mongodb:MongoDB instance'
            'mongodb-operator:MongoDB operator app'
            'nats:NATS'
            'nfs:NFS provisioner'
            'opencost:OpenCost'
            'pg-ui:PostgreSQL UI'
            'pgadmin:PgAdmin'
            'redis-stack:Redis Stack'
            'rook-ceph-cluster:Rook Ceph cluster'
            'rook-ceph-operator:Rook Ceph operator'
            'trivy:Trivy scanner'
            'coredns:CoreDNS'
        )
    fi

    _arguments -C \
        '1:command:->command' \
        '2:subcommand:->subcommand' \
        '3:item:->item' \
        '4:flag:->flag' \
        && return 0

    case $state in
        command)
            _describe -t commands 'k8s-local commands' commands
            ;;
        subcommand)
            case $words[1] in
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
            case $words[1] in
                install)
                    case $words[2] in
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
            case $words[1] in
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
