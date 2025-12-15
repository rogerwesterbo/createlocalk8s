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
            'create:Create a new Kubernetes cluster (kind or talos)'
            'c:Alias for create'
            'delete:Delete an existing cluster'
            'd:Alias for delete'
            'list:List all clusters'
            'ls:Alias for list'
            'details:Show cluster details'
            'dt:Alias for details'
            'k8sdetails:Show detailed Kubernetes resources'
            'k8s:Alias for k8sdetails'
            'kubeconfig:Get kubeconfig for a cluster'
            'kc:Alias for kubeconfig'
            'help:Show help message'
            'h:Alias for help'
            'helm:Manage Helm components'
            'apps:Manage ArgoCD applications'
            'install:Install Helm component or ArgoCD app'
        )
    fi

    # --- Get cluster names from directories ---
    local -a clusters
    if [[ -d clusters ]]; then
        local cluster_list
        cluster_list=($(find clusters -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | grep -v '^\\.'))
        for cluster in "${cluster_list[@]}"; do
            clusters+=("${cluster}:Cluster")
        done
    fi

    # --- Dynamic Helm components ---
    # Expect something like a newline list or table; we take first column tokens
    local helm_out
    helm_out="$($script helm list 2>/dev/null)"
    if [[ -n "$helm_out" ]]; then
        # Remove header lines commonly containing NAME or similar
        local helm_list
        helm_list=($(echo "$helm_out" | awk 'NR==1 && tolower($0) ~ /name/ {next} {print $1}' | sed -E '/^$/d'))
        helm_list=(${helm_list:#(NAME|NAME:)*})
        # Map to "name:Helm component"
        for component in "${helm_list[@]}"; do
            helm_components+=("${component}:Helm component")
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
            'keycloak:Keycloak identity and access management'
            'kite:Kite Kubernetes dashboard'
            'kube-prometheus-stack:Prometheus stack'
            'kubeview:KubeView'
            'local-path-provisioner:Local Path Provisioner'
            'localpathprovisioner:Local Path Provisioner'
            'metallb:MetalLB'
            'metrics-server:Metrics Server'
            'minio:MinIO'
            'mongodb-instance:MongoDB instance'
            'mongodb-operator:MongoDB operator'
            'nats:NATS'
            'nfs:NFS provisioner'
            'nginx:NGINX ingress'
            'nginx-ingress:NGINX ingress'
            'openbao:OpenBao'
            'opencost:OpenCost'
            'pgadmin:PgAdmin'
            'postgres:CloudNativePG operator + cluster'
            'prometheus:Kube Prometheus Stack'
            'rook-ceph-cluster:Rook Ceph cluster'
            'rook-ceph-operator:Rook Ceph operator'
            'rookcephcluster:Rook Ceph cluster'
            'rookcephoperator:Rook Ceph operator'
            'trivy:Trivy'
            'valkey:Valkey key-value store'
        )
    fi

    # --- Dynamic Argo apps ---
    local apps_out
    apps_out="$($script apps list 2>/dev/null)"
    if [[ -n "$apps_out" ]]; then
        local apps_list
        apps_list=($(echo "$apps_out" | awk '{print $1}' | sed -E '/^(NAME|Name|#|$)/d'))
        for app in "${apps_list[@]}"; do
            argo_apps+=("${app}:ArgoCD app")
        done
    fi
    # Fallback static list
    if (( ${#argo_apps} == 0 )); then
        argo_apps=(
            'nyancat:Nyancat demo'
            'prometheus:Kube Prometheus Stack'
            'cert-manager:Cert Manager app'
            'certmanager:Cert Manager app'
            'cnpg-cluster:CNPG cluster'
            'crossplane:Crossplane app'
            'falco:Falco'
            'keycloak:Keycloak identity and access management'
            'kite:Kite Kubernetes dashboard'
            'kubeview:KubeView'
            'metallb:MetalLB'
            'metrics-server:Metrics Server'
            'minio:MinIO'
            'mongodb:MongoDB instance'
            'mongodb-instance:MongoDB instance'
            'mongodb-operator:MongoDB operator app'
            'nats:NATS'
            'nfs:NFS provisioner'
            'nginx:Ingress-Nginx controller'
            'opencost:OpenCost'
            'pg-ui:PostgreSQL UI'
            'pgadmin:PgAdmin'
            'postgres:CloudNativePG operator + cluster'
            'rook-ceph-cluster:Rook Ceph cluster'
            'rook-ceph-operator:Rook Ceph operator'
            'trivy:Trivy scanner'
            'valkey:Valkey key-value store'
            'coredns:CoreDNS'
            'local-path-provisioner:Local Path Provisioner'
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
            case $words[2] in
                helm)
                    _values 'helm commands' 'list[List available Helm components]'
                    ;;
                apps)
                    _values 'apps commands' 'list[List available ArgoCD apps]'
                    ;;
                install)
                    _values 'install types' 'helm[Install Helm component]' 'apps[Install ArgoCD app]'
                    ;;
                create|c)
                    if [[ $words[3] == --provider=* || $words[3] == --provider ]]; then
                        _values 'provider' 'kind[Kubernetes in Docker]' 'talos[Talos Linux]'
                    else
                        _describe -t clusters 'Clusters' clusters
                        _values 'flags' '--provider[Specify provider: kind or talos]'
                    fi
                    ;;
                delete|d|details|dt|k8sdetails|k8s|kubeconfig|kc)
                    _describe -t clusters 'Clusters' clusters
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
