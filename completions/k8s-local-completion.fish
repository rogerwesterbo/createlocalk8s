# Fish completion for k8s-local / kl / create-cluster

function __k8s_local_script_names
    printf "k8s-local\nkl\ncreate-cluster\nk8s-local.sh\nkl.sh\ncreate-cluster.sh\n"
end

function __k8s_local_help_cmds
    set -l s (commandline -opc)[1]
    test -z "$s"; and return
    set -l out ($s help ^ /dev/null; or $s --help ^ /dev/null)
    if test -n "$out"
        set -l extracting 0
        for l in $out
            if string match -qr '^[[:space:]]*Commands:' -- $l
                set extracting 1
                continue
            end
            if test $extracting -eq 1
                if test -z (string trim -- $l)
                    break
                end
                set -l name (string match -r '^[[:space:]]*([A-Za-z0-9_-]+)' -- $l | string trim)
                test -n "$name"; and echo $name
            end
        end
    end
end

function __k8s_local_commands
    set -l cmds (__k8s_local_help_cmds)
    if test (count $cmds) -eq 0
        set cmds create c delete d list ls details dt k8sdetails k8s kubeconfig kc help h helm apps install
    end
    printf "%s\n" $cmds
end

function __k8s_local_helm_components
    set -l s (commandline -opc)[1]
    set -l out ($s helm list ^ /dev/null)
    if test -n "$out"
        for l in $out
            string match -qr '^(NAME|Name)' -- $l; and continue
            set -l f (string split ' ' -- $l)[1]
            test -n "$f"; and echo $f
        end
    else
        printf "%s\n" argocd cert-manager cnpg crossplane falco hashicorp-vault kube-prometheus-stack kubeview metallb metrics-server minio mongodb-operator nats nfs nginx-ingress opencost pgadmin prometheus redis-stack rook-ceph-operator trivy
    end
end

function __k8s_local_argo_apps
    set -l s (commandline -opc)[1]
    set -l out ($s apps list ^ /dev/null)
    if test -n "$out"
        for l in $out
            string match -qr '^(NAME|Name|#)' -- $l; and continue
            set -l f (string split ' ' -- $l)[1]
            test -n "$f"; and echo $f
        end
    else
        printf "%s\n" nyancat prometheus cert-manager cnpg-cluster crossplane falco hashicorp-vault kubeview metallb metrics-server minio mongodb mongodb-operator nats nfs opencost pg-ui pgadmin redis-stack rook-ceph-cluster rook-ceph-operator trivy coredns
    end
end

function __k8s_local_clusters
    if test -d clusters
        find clusters -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | grep -v '^\.'
    end
end

# Clear previous to avoid duplicates when re-sourcing
for n in (__k8s_local_script_names)
    complete -c $n -f
end

# Command position 1
for n in (__k8s_local_script_names)
    complete -c $n -n "commandline -opc | count | test (count (commandline -opc)) -eq 1" \
        -a "(__k8s_local_commands)" -d "k8s-local command"
end

# Subcommands for helm/apps/install
for n in (__k8s_local_script_names)
    # helm/apps list
    complete -c $n -n "__fish_seen_subcommand_from helm; and test (count (commandline -opc)) -eq 2" -a list -d "List Helm components"
    complete -c $n -n "__fish_seen_subcommand_from apps; and test (count (commandline -opc)) -eq 2" -a list -d "List Argo apps"
    # install types
    complete -c $n -n "__fish_seen_subcommand_from install; and test (count (commandline -opc)) -eq 2" -a "helm apps" -d "Install type"
end

# Items for install helm/apps
for n in (__k8s_local_script_names)
    complete -c $n -n "__fish_seen_subcommand_from install; and contains helm (commandline -opc | tail -n1)" \
        -a "(__k8s_local_helm_components)" -d "Helm component"
    complete -c $n -n "__fish_seen_subcommand_from install; and contains apps (commandline -opc | tail -n1)" \
        -a "(__k8s_local_argo_apps)" -d "Argo app"
end

# Cluster names for cluster-oriented commands (pos 2)
set -l cluster_cmds create c delete d details dt k8sdetails k8s kubeconfig kc
for n in (__k8s_local_script_names)
    for c in $cluster_cmds
        complete -c $n -n "__fish_seen_subcommand_from $c; and test (count (commandline -opc)) -eq 2" \
            -a "(__k8s_local_clusters)" -d "Cluster"
    end
end

# Provider flag for create command
for n in (__k8s_local_script_names)
    complete -c $n -n "__fish_seen_subcommand_from create c" -l provider -d "Provider (kind or talos)" -a "kind talos"
end

# Flags
for n in (__k8s_local_script_names)
    complete -c $n -n "__fish_seen_subcommand_from install" -a "--dry-run" -d "Show planned actions"
end
