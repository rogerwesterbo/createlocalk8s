#!/bin/bash

# Talos Provider Implementation
# Implements the provider interface for Talos Linux (running in Docker)

talos_check_prerequisites() {
    local missing=()

    if ! command -v talosctl &> /dev/null; then
        missing+=("talosctl")
    fi

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${red}Missing prerequisites for Talos provider:${clear}"
        printf '%s\n' "${missing[@]}"
        echo -e "\n${yellow}Install talosctl:${clear}"
        echo -e "  curl -sL https://talos.dev/install | sh"
        echo -e "\n${yellow}Or via Homebrew:${clear}"
        echo -e "  brew install siderolabs/tap/talosctl"
        return 1
    fi

    return 0
}

talos_create_cluster() {
    local cluster_name="$1"
    local config_file="$2"
    local k8s_version="$3"
    local controlplane_count="$4"
    local worker_count="$5"
    local http_port="$6"
    local https_port="$7"

    local talos_dir="$clustersDir/$cluster_name-talos"
    mkdir -p "$talos_dir"

    # Generate Talos machine configuration files.
    # These are for reference and potential future use (e.g. adding nodes manually).
    # talosctl cluster create will generate its own configs internally.
    echo -e "${yellow}\n⏰ Generating Talos machine configuration${clear}"
    # The endpoint needs to be the address of the first controlplane, reachable from other nodes.
    # In the docker network created by talosctl, this will be the container name.
    local endpoint_host
    endpoint_host=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')-controlplane-1
    (cd "$talos_dir" && talosctl gen config "$cluster_name" "https://$endpoint_host:6443" --kubernetes-version "$k8s_version" --additional-sans "127.0.0.1" >/dev/null ||
    {
        echo -e "${red} 🛑 Could not generate Talos config${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Creating Talos cluster using talosctl${clear}"

    # Build talosctl cluster create command
    local create_cmd="talosctl cluster create"
    create_cmd="$create_cmd --name $cluster_name"
    create_cmd="$create_cmd --controlplanes $controlplane_count"
    create_cmd="$create_cmd --workers $worker_count"
    create_cmd="$create_cmd --kubernetes-version $k8s_version"

    # Add port mappings for first control plane
    create_cmd="$create_cmd --exposed-ports $http_port:80/tcp,$https_port:443/tcp"

    # Wait for cluster to be ready
    create_cmd="$create_cmd --wait --wait-timeout 5m"

    # Create the cluster using talosctl
    echo -e "${yellow}Running: talosctl cluster create with $controlplane_count control plane(s) and $worker_count worker(s)${clear}"

    ($create_cmd ||
    {
        echo -e "${red} 🛑 Could not create Talos cluster${clear}"
        return 1
    }) & spinner

    # talosctl automatically generates configs, let's move them to our talos dir
    if [ -d "$HOME/.talos/clusters/$cluster_name" ]; then
        cp "$HOME/.talos/clusters/$cluster_name/talosconfig" "$talos_dir/talosconfig" 2>/dev/null || true
    fi

    # Get kubeconfig
    echo -e "${yellow}\n⏰ Retrieving kubeconfig${clear}"
    (talos_get_kubeconfig "$cluster_name" "$clustersDir/$cluster_name-kube.config" ||
    {
        echo -e "${red} 🛑 Could not retrieve kubeconfig${clear}"
        return 1
    }) & spinner

    # Set the context
    export KUBECONFIG="$clustersDir/$cluster_name-kube.config"

    # Update context name to match our convention
    kubectl config rename-context "admin@$cluster_name" "admin@$cluster_name" 2>/dev/null || true

    # Wait for nodes to be ready (talosctl should have done this, but double-check)
    echo -e "${yellow}\n⏰ Verifying cluster nodes are ready${clear}"
    (kubectl wait --for=condition=Ready nodes --all --timeout=60s ||
    {
        echo -e "${red} 🛑 Cluster nodes not ready in time${clear}"
        return 1
    }) & spinner

    echo -e "${yellow} ✅ Talos cluster created successfully${clear}"
    return 0
}

talos_delete_cluster() {
    local cluster_name="$1"

    echo -e "${yellow}\n⏰ Deleting Talos cluster using talosctl${clear}"

    # Use talosctl to destroy the cluster (handles all containers and networking)
    (talosctl cluster destroy --name "$cluster_name" ||
    {
        echo -e "${yellow} ⚠️  talosctl cluster destroy failed, attempting manual cleanup${clear}"

        # Fallback: manual cleanup if talosctl fails
        local containers
        containers=$(docker ps -a --filter "name=${cluster_name}-" --format "{{.Names}}")
        if [ -n "$containers" ]; then
            for container in $containers; do
                echo -e "${yellow}Stopping and removing container: $container${clear}"
                docker stop "$container" >/dev/null 2>&1 && docker rm "$container" >/dev/null 2>&1
            done
        fi

        # Try to remove network
        docker network rm "talos-${cluster_name}" >/dev/null 2>&1 || true
    }) & spinner

    # Clean up talosctl stored configs
    rm -rf "$HOME/.talos/clusters/$cluster_name" 2>/dev/null || true

    echo -e "${yellow} ✅ Talos cluster deleted${clear}"
    return 0
}

talos_list_clusters() {
    # List clusters by finding their control plane containers in Docker
    docker ps -a --filter "name=-controlplane-1$" --format "{{.Names}}" 2>/dev/null | sed 's/-controlplane-1$//' | sort -u || true
}

talos_validate_cluster_exists() {
    local cluster_name="$1"

    if [ -z "$cluster_name" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty${clear}"
        exit 1
    fi

    # Check if cluster exists by looking for its control plane container
    local container_name="${cluster_name}-controlplane-1"
    if ! docker ps -a --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${red}\n🛑 Talos cluster '${cluster_name}' not found${clear}"
        echo -e "${yellow}\nAvailable Talos clusters:${clear}"
        talos_list_clusters
        exit 1
    fi
}

talos_validate_cluster_not_exists() {
    local cluster_name="$1"

    if [ -z "$cluster_name" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty${clear}"
        exit 1
    fi

    # Check if cluster already exists by looking for its control plane container
    local container_name="${cluster_name}-controlplane-1"
    if docker ps -a --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${red}\n🛑 Talos cluster '${cluster_name}' already exists${clear}"
        echo -e "${yellow}\nPlease choose a different name or delete the existing cluster first:${clear}"
        echo -e "  ${blue}./kl.sh delete ${cluster_name}${clear}"
        exit 1
    fi
}

talos_get_kubeconfig() {
    local cluster_name="$1"
    local output_file="$2"

    # Find the host port mapped to the Talos API (50000)
    local talos_api_port
    talos_api_port=$(docker port "${cluster_name}-controlplane-1" 50000/tcp | awk -F: '{print $2}')

    # if [ -z "$talos_api_port" ]; then
    #     echo -e "${red} 🛑 Could not find mapped Talos API port for ${cluster_name}-controlplane-1. Kubeconfig retrieval might fail.${clear}" >&2
    #     local node_addr="127.0.0.1"
    # else
    #     local node_addr="127.0.0.1:${talos_api_port}"
    # fi

    # talosctl can export kubeconfig directly by cluster name
    talosctl kubeconfig "$output_file" \
        --force \
        --merge=true \
        --cluster "$cluster_name" \
        --nodes "127.0.0.1" 2>/dev/null

    if [ $? -ne 0 ]; then
        return 1
    fi

    # Find the host port mapped to the Kubernetes API (6443)
    local k8s_api_port
    k8s_api_port=$(docker port "${cluster_name}-controlplane-1" 6443/tcp | awk -F: '{print $2}')

    if [ -z "$k8s_api_port" ]; then
        echo -e "${red} 🛑 Could not find mapped Kubernetes API port for ${cluster_name}-controlplane-1. Kubeconfig server URL cannot be updated.${clear}" >&2
        return 1
    fi

    # Update the server URL in the kubeconfig to point to the host
    KUBECONFIG="$output_file" kubectl config set-cluster "$cluster_name" --server="https://127.0.0.1:${k8s_api_port}" >/dev/null

    return $?
}

talos_get_cluster_context() {
    local cluster_name="$1"
    echo "admin@$cluster_name"
}

talos_setup_ingress() {
    local cluster_name="$1"
    local http_port="$2"
    local https_port="$3"

    # Talos uses standard Nginx ingress (no special patches needed)
    echo -e "${yellow}Installing Nginx Ingress Controller for Talos${clear}"

    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml ||
    {
        echo -e "${red} 🛑 Could not install Nginx controller${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for Nginx ingress controller to be ready${clear}"
    sleep 10
    (kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=180s ||
    {
        echo -e "${red} 🛑 Nginx ingress controller not ready in time${clear}"
        return 1
    }) & spinner

    # Patch the ingress service to use host ports
    echo -e "${yellow}\n⏰ Configuring ingress for host network access${clear}"
    (kubectl patch service -n ingress-nginx ingress-nginx-controller \
        -p '{"spec":{"type":"NodePort"}}' ||
    {
        echo -e "${yellow} ⚠️  Could not patch ingress service (may already be configured)${clear}"
    }) & spinner

    echo -e "${yellow} ✅ Done installing Nginx Ingress Controller${clear}"
    return 0
}

talos_get_info() {
    echo "Provider: talos"
    echo "Provider URL: https://www.talos.dev/"
    echo "Container Runtime: Docker (Talos in Docker mode)"
}

talos_supports_multi_cluster() {
    echo "yes"
}

# # Talos-specific helper: Get node IPs
# talos_get_node_ips() {
#     local cluster_name="$1"
#     docker ps --filter "name=${cluster_name}-" --format "{{.Names}}" | while read container; do
#         local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")
#         echo "$container: $ip"
#     done
# }

# Talos-specific helper: Get node IPs
talos_get_node_ips() {
    local cluster_name="$1"
    docker ps --filter "name=${cluster_name}-" --format "{{.Names}}" | while read container; do
        local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")
        echo "$container: $ip"
    done
}

# Talos-specific helper: Get talosctl endpoint
talos_get_endpoint() {
    local cluster_name="$1"
    echo "127.0.0.1:6443"
}
