#!/bin/bash

# Provider-agnostic cluster operations
# These functions work on any Kubernetes cluster regardless of provider

# Install ArgoCD using Helm (provider-agnostic)
install_argocd_generic() {
    local cluster_name="$1"

    echo -e "${yellow}Installing ArgoCD${clear}"
    helm repo add argo https://argoproj.github.io/argo-helm
    (helm install argocd argo/argo-cd --namespace argocd --create-namespace --set configs.params.server.insecure=true ||
    {
        echo -e "${red} 🛑 Could not install argocd into cluster ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\nPatch ArgoCD to allow insecure server${clear}"
    (kubectl patch configmaps -n argocd argocd-cmd-params-cm --type merge -p '{"data": { "server.insecure": "true" }}' ||
    {
        echo -e "${red} 🛑 Could not patch argocd configmap ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\nRestarting ArgoCD server${clear}"
    (kubectl -n argocd rollout restart deployment argocd-server ||
    {
        echo -e "${red} 🛑 Could not restart argocd server ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for ArgoCD to be ready${clear}"
    sleep 10
    (kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=180s ||
    {
        echo -e "${red} 🛑 ArgoCD deployment not ready in time ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\nInstalling ArgoCD Ingress${clear}"
    (kubectl apply -f "$argocd_ingress_yaml" ||
    {
        echo -e "${red} 🛑 Could not install argocd ingress into cluster ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow} ✅ Done installing ArgoCD${clear}"
    return 0
}

# Get ArgoCD admin password (provider-agnostic)
get_argocd_password() {
    kubectl get secrets -n argocd argocd-initial-admin-secret -o json 2>/dev/null | jq -r '.data.password' | base64 -d
}

# Wait for pods to be ready in a namespace (provider-agnostic)
wait_for_pods_ready() {
    local namespace="$1"
    local timeout="${2:-180s}"

    echo -e "${yellow}⏰ Waiting for pods in namespace '$namespace' to be ready (timeout: $timeout)${clear}"
    kubectl wait pods --for=condition=Ready --all -n "$namespace" --timeout="$timeout" 2>/dev/null
}

# Get cluster info (provider-agnostic)
get_cluster_info() {
    echo -e "${yellow}\n🚀 Cluster details${clear}\n"
    kubectl cluster-info

    echo -e "${yellow}\n🚀 Nodes${clear}\n"
    kubectl get nodes

    echo -e "${yellow}\n🚀 Pods${clear}\n"
    kubectl get pods --all-namespaces

    echo -e "${yellow}\n🚀 Services${clear}\n"
    kubectl get services --all-namespaces

    echo -e "${yellow}\n🚀 Ingresses${clear}\n"
    kubectl get ingresses --all-namespaces
}

# Get detailed Kubernetes resources (provider-agnostic)
get_kubernetes_details() {
    get_cluster_info

    echo -e "${yellow}\n🚀 Deployments${clear}\n"
    kubectl get deployments --all-namespaces

    echo -e "${yellow}\n🚀 StatefulSets${clear}\n"
    kubectl get statefulsets --all-namespaces

    echo -e "${yellow}\n🚀 DaemonSets${clear}\n"
    kubectl get daemonsets --all-namespaces

    echo -e "${yellow}\n🚀 ConfigMaps${clear}\n"
    kubectl get configmaps --all-namespaces

    echo -e "${yellow}\n🚀 Secrets${clear}\n"
    kubectl get secrets --all-namespaces

    echo -e "${yellow}\n🚀 Persistent Volumes${clear}\n"
    kubectl get pv

    echo -e "${yellow}\n🚀 Persistent Volume Claims${clear}\n"
    kubectl get pvc --all-namespaces

    echo -e "${yellow}\n🚀 Storage Classes${clear}\n"
    kubectl get storageclass
}

# Switch to cluster context (provider-agnostic wrapper)
switch_to_cluster_context() {
    local context_name="$1"

    echo -e "${yellow}\n🔄 Switching to cluster context: ${blue}$context_name${clear}"
    kubectl config use-context "$context_name" 2>/dev/null || {
        echo -e "${red} 🛑 Could not switch to cluster context${clear}"
        return 1
    }
    return 0
}

# Check if running more than one cluster (works with any provider via cluster metadata)
is_running_multiple_clusters() {
    local provider="${1:-kind}"  # Default to kind for backward compatibility

    # Count clusters for the current provider
    local cluster_count=0

    # Check all cluster provider files
    for provider_file in "$clustersDir"/*-provider.txt; do
        [ -f "$provider_file" ] || continue
        local cluster_provider=$(cat "$provider_file")
        if [ "$cluster_provider" == "$provider" ]; then
            cluster_count=$((cluster_count + 1))
        fi
    done

    # Also check if provider-specific list shows multiple
    if [ "$cluster_count" -ge 2 ]; then
        echo "yes"
    else
        echo "no"
    fi
}

# Find a free port (provider-agnostic)
find_free_port() {
    local port
    # Try ports in range 8080-65535
    for port in $(seq 8080 65535); do
        if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "$port"
            return 0
        fi
    done
    # Fallback: let the system assign a random port
    python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' 2>/dev/null || echo "8080"
}

# Determine ports for cluster (provider-agnostic)
determine_cluster_ports() {
    local provider="$1"
    local http_port=80
    local https_port=443

    # Check if we need to assign random ports
    if [ "$(is_running_multiple_clusters "$provider")" == "yes" ]; then
        echo -e "${yellow}\n🚨 Multiple clusters detected. Assigning random ports to avoid conflicts.${clear}"
        http_port=$(find_free_port)
        https_port=$(find_free_port)
    fi

    echo "$http_port $https_port"
}

# Install Nyancat demo application (provider-agnostic)
install_nyancat_demo() {
    local cluster_name="$1"

    echo -e "${yellow}Installing Nyancat demo application${clear}"

    if ! kubectl get namespace argocd &>/dev/null; then
        echo -e "${red} 🛑 ArgoCD is not installed. Please install ArgoCD first.${clear}"
        return 1
    fi

    install_nyancat_application
    return $?
}

# Display post-creation cluster information (provider-agnostic)
display_cluster_info() {
    local cluster_name="$1"
    local provider="$2"
    local http_port="$3"
    local https_port="$4"
    local argocd_installed="${5:-no}"
    local argocd_password="${6:-}"

    if [ "$argocd_installed" == "yes" ]; then
        echo -e "${yellow} 🚀 ArgoCD is ready to use${clear}"

        if [ "$http_port" != "80" ]; then
            echo -e "${yellow}\nOpen the ArgoCD UI in your browser: http://argocd.localtest.me:$http_port${clear}"
        else
            echo -e "${yellow}\nOpen the ArgoCD UI in your browser: http://argocd.localtest.me${clear}"
        fi

        echo -e "${yellow}\n 🔑 ArgoCD Username:${blue} admin${clear}"
        echo -e "${yellow} 🔑 ArgoCD Password:${blue} $argocd_password${clear}"
    fi

    if [ "$http_port" != "80" ] || [ "$https_port" != "443" ]; then
        echo -e "${yellow}\n 🚀 Cluster ports have been customized${clear}"
        echo -e "${yellow} Cluster http port: $http_port${clear}"
        echo -e "${yellow} Cluster https port: $https_port${clear}"
        echo -e "${yellow}\n To access an application add the port to the URL:${clear}"
        echo -e "${yellow} Example: http://nyancat.localtest.me:$http_port${clear}"
    fi

    echo -e "${yellow}\n To see cluster details, type: ${blue}./kl.sh details $cluster_name${clear}"
    echo -e "${yellow} To delete cluster, type: ${blue}./kl.sh delete $cluster_name${clear}"
}

# Export cluster info to file (provider-agnostic)
write_cluster_info_file() {
    local cluster_name="$1"
    local provider="$2"
    local controlplane_count="$3"
    local worker_count="$4"
    local k8s_version="$5"
    local http_port="$6"
    local https_port="$7"
    local argocd_installed="${8:-no}"
    local argocd_password="${9:-}"
    local cluster_info_file="${10}"

    # Clear or create file
    if [ -e "$cluster_info_file" ] && [ -r "$cluster_info_file" ] && [ -w "$cluster_info_file" ]; then
        truncate -s 0 "$cluster_info_file"
    fi

    cat > "$cluster_info_file" <<EOF
Cluster name: $cluster_name
Provider: $provider
Control plane count: $controlplane_count
Worker count: $worker_count
Kubernetes version: $k8s_version
Cluster http port: $http_port
Cluster https port: $https_port
Install ArgoCD: $argocd_installed
EOF

    if [ "$argocd_installed" == "yes" ] && [ -n "$argocd_password" ]; then
        cat >> "$cluster_info_file" <<EOF
ArgoCD admin password: $argocd_password
ArgoCD admin GUI port forwarding: kubectl port-forward -n argocd services/argocd-server 58080:443
ArgoCD admin GUI URL: http://localhost:58080
EOF
    fi
}
