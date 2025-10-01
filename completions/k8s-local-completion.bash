#!/usr/bin/env bash
# Bash completion script for k8s-local.sh / kl.sh / create-cluster.sh

_k8s_local_completion() {
    local cur prev words cword
    _init_completion || return

    # Main commands
    local commands="create delete list info config start stop help helm apps install"
    
    # Helm components (from registry)
    local helm_components="argocd cert-manager cnpg crossplane falco hashicorp-vault kube-prometheus-stack kubeview metallb minio mongodb-operator nats nfs nginx-ingress opencost pgadmin redis-stack rook-ceph-operator trivy"
    
    # ArgoCD apps (from registry)
    local argo_apps="nyancat prometheus cert-manager cnpg-cluster crossplane falco hashicorp-vault kubeview metallb minio mongodb mongodb-operator nats nfs opencost pg-ui pgadmin redis-stack rook-ceph-cluster rook-ceph-operator trivy coredns"

    case "${cword}" in
        1)
            # First argument: main commands
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            # Second argument depends on first
            case "${prev}" in
                helm)
                    COMPREPLY=($(compgen -W "list" -- "${cur}"))
                    ;;
                apps)
                    COMPREPLY=($(compgen -W "list" -- "${cur}"))
                    ;;
                install)
                    COMPREPLY=($(compgen -W "helm apps" -- "${cur}"))
                    ;;
                create|delete|list|info|config|start|stop)
                    # These commands typically take cluster names
                    # Could potentially scan clusters/ directory for cluster names
                    ;;
            esac
            ;;
        3)
            # Third argument
            case "${words[1]}" in
                install)
                    case "${prev}" in
                        helm)
                            # Suggest helm components
                            COMPREPLY=($(compgen -W "${helm_components}" -- "${cur}"))
                            ;;
                        apps)
                            # Suggest argo apps
                            COMPREPLY=($(compgen -W "${argo_apps}" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
        4)
            # Fourth argument - could be --dry-run
            case "${words[1]}" in
                install)
                    COMPREPLY=($(compgen -W "--dry-run" -- "${cur}"))
                    ;;
            esac
            ;;
    esac

    return 0
}

# Register completion for all three script names
complete -F _k8s_local_completion k8s-local.sh
complete -F _k8s_local_completion kl.sh
complete -F _k8s_local_completion create-cluster.sh

# Also register without .sh extension in case they're in PATH
complete -F _k8s_local_completion k8s-local
complete -F _k8s_local_completion kl
complete -F _k8s_local_completion create-cluster
