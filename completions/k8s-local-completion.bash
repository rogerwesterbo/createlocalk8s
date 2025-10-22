#!/usr/bin/env bash
# Bash completion script for k8s-local.sh / kl.sh / create-cluster.sh

_k8s_local_completion() {
    local cur prev words cword
    _init_completion || return

    local script="${COMP_WORDS[0]}"

    # --- Dynamic helpers (with simple caching per shell session) ---
    _k8s_local_cache_init() {
        [[ -n "${_K8S_LOCAL_CACHE_DONE}" ]] && return
        _K8S_LOCAL_CACHE_DONE=1
        _K8S_LOCAL_CMDS=""
        _K8S_LOCAL_HELM=""
        _K8S_LOCAL_APPS=""
    }

    _k8s_local_get_commands() {
        _k8s_local_cache_init
        if [[ -z "$_K8S_LOCAL_CMDS" ]]; then
            local help_out
            help_out="$("$script" help 2>/dev/null || "$script" --help 2>/dev/null)"
            if [[ -n "$help_out" ]]; then
                _K8S_LOCAL_CMDS="$(echo "$help_out" | awk '
                    /^[[:space:]]*Commands:/ {collect=1;next}
                    collect && /^[[:space:]]*$/ {collect=0}
                    collect { 
                        if (match($0,/^[[:space:]]*([[:alnum:]_-]+)/,m)) print m[1]
                    }' | tr '\n' ' ')"
            fi
            [[ -z "$_K8S_LOCAL_CMDS" ]] && _K8S_LOCAL_CMDS="create delete list info config start stop help helm apps install"
        fi
        printf '%s' "$_K8S_LOCAL_CMDS"
    }

    _k8s_local_get_helm_components() {
        _k8s_local_cache_init
        if [[ -z "$_K8S_LOCAL_HELM" ]]; then
            local out
            out="$("$script" helm list 2>/dev/null)"
            if [[ -n "$out" ]]; then
                _K8S_LOCAL_HELM="$(echo "$out" | awk 'NR==1 && tolower($0) ~ /name/ {next} {print $1}' | sed -E '/^$/d' | tr '\n' ' ')"
            fi
            [[ -z "$_K8S_LOCAL_HELM" ]] && _K8S_LOCAL_HELM="argocd cert-manager cnpg crossplane falco hashicorp-vault kube-prometheus-stack kubeview metallb metrics-server minio mongodb-operator nats nfs nginx-ingress opencost pgadmin prometheus redis-stack rook-ceph-operator trivy"
        fi
        printf '%s' "$_K8S_LOCAL_HELM"
    }

    _k8s_local_get_argo_apps() {
        _k8s_local_cache_init
        if [[ -z "$_K8S_LOCAL_APPS" ]]; then
            local out
            out="$("$script" apps list 2>/dev/null)"
            if [[ -n "$out" ]]; then
                _K8S_LOCAL_APPS="$(echo "$out" | awk '{print $1}' | sed -E '/^(NAME|Name|#|$)/d' | tr '\n' ' ')"
            fi
            [[ -z "$_K8S_LOCAL_APPS" ]] && _K8S_LOCAL_APPS="nyancat prometheus cert-manager cnpg-cluster crossplane falco hashicorp-vault kubeview metallb metrics-server minio mongodb mongodb-operator nats nfs opencost pg-ui pgadmin redis-stack rook-ceph-cluster rook-ceph-operator trivy coredns"
        fi
        printf '%s' "$_K8S_LOCAL_APPS"
    }

    _k8s_local_get_clusters() {
        # Suggest cluster directory names from clusters/
        if [[ -d clusters ]]; then
            find clusters -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | grep -v '^\.' | tr '\n' ' '
        fi
    }

    local commands="$(_k8s_local_get_commands)"
    local helm_components="$(_k8s_local_get_helm_components)"
    local argo_apps="$(_k8s_local_get_argo_apps)"
    local clusters="$(_k8s_local_get_clusters)"

    case "${cword}" in
        1)
            # First argument: main commands
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            # Second argument depends on first
            case "${prev}" in
                helm|apps)
                    COMPREPLY=($(compgen -W "list" -- "${cur}"))
                    ;;
                install)
                    COMPREPLY=($(compgen -W "helm apps" -- "${cur}"))
                    ;;
                create|c)
                    # Support --provider flag for create command
                    if [[ ${cur} == -* ]]; then
                        COMPREPLY=($(compgen -W "--provider" -- "${cur}"))
                    else
                        [[ -n "$clusters" ]] && COMPREPLY=($(compgen -W "${clusters}" -- "${cur}"))
                    fi
                    ;;
                delete|d|details|dt|k8sdetails|k8s|kubeconfig|kc)
                    # These commands take cluster names
                    [[ -n "$clusters" ]] && COMPREPLY=($(compgen -W "${clusters}" -- "${cur}"))
                    ;;
                list|ls)
                    # list doesn't take arguments
                    COMPREPLY=()
                    ;;
            esac
            ;;
        3)
            # Third argument
            case "${words[1]}" in
                create|c)
                    # Handle --provider=kind or --provider=talos
                    if [[ ${prev} == "--provider" ]]; then
                        COMPREPLY=($(compgen -W "kind talos" -- "${cur}"))
                    elif [[ ${cur} == --provider=* ]]; then
                        COMPREPLY=($(compgen -W "kind talos" -P "--provider=" -- "${cur#--provider=}"))
                    fi
                    ;;
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
