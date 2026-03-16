#!/bin/bash

# Talos Provider Implementation
# Implements the provider interface for Talos Linux (running in Docker)

# Get the installed talosctl version (major.minor)
talos_get_version() {
    local version
    version=$(talosctl version --client 2>/dev/null | grep "Tag:" | awk '{print $2}' | sed 's/^v//')
    if [ -z "$version" ]; then
        echo ""
        return 1
    fi
    # Return major.minor only
    echo "$version" | cut -d. -f1,2
}

# Get supported Kubernetes versions for the installed talosctl version
# Based on: https://docs.siderolabs.com/talos/v1.11/getting-started/support-matrix
talos_get_supported_k8s_versions() {
    local talos_version
    talos_version=$(talos_get_version)
    
    if [ -z "$talos_version" ]; then
        echo -e "${red}Could not determine talosctl version${clear}" >&2
        return 1
    fi
    
    # Talos version to Kubernetes version support matrix
    # Use case statement to avoid associative array issues with version keys
    # Note: Full patch versions are required (e.g., 1.34.1 not 1.34)
    # Based on: https://www.talos.dev/v1.12/introduction/support-matrix/
    local k8s_versions=""
    case "$talos_version" in
        "1.12") k8s_versions="1.35.2 1.34.1 1.33.1 1.32.3 1.31.6 1.30.10" ;;
        "1.11") k8s_versions="1.34.1 1.33.1 1.32.3 1.31.6 1.30.10 1.29.14" ;;
        "1.10") k8s_versions="1.33.1 1.32.3 1.31.6 1.30.10 1.29.14 1.28.15" ;;
        "1.9")  k8s_versions="1.32.3 1.31.6 1.30.10 1.29.14 1.28.15 1.27.16" ;;
        "1.8")  k8s_versions="1.31.6 1.30.10 1.29.14 1.28.15 1.27.16 1.26.15" ;;
        *)
            echo -e "${yellow}Warning: Talos version $talos_version not in support matrix, using latest known versions${clear}" >&2
            k8s_versions="1.35.2 1.34.1 1.33.1 1.32.3 1.31.6 1.30.10"
            ;;
    esac
    
    echo "$k8s_versions"
}

# Populate talosk8sversions array dynamically based on installed talosctl
talos_populate_k8s_versions() {
    local k8s_versions
    k8s_versions=$(talos_get_supported_k8s_versions)
    
    if [ -z "$k8s_versions" ]; then
        return 1
    fi
    
    # Convert space-separated string to array (works in both bash and zsh)
    # shellcheck disable=SC2034
    talosk8sversions=($k8s_versions)
    
    return 0
}

talos_check_prerequisites() {
    local missing=()

    if ! command -v talosctl &> /dev/null; then
        missing+=("talosctl")
    fi

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${red}Missing prerequisites for Talos provider:${clear}"
        printf '%s\n' "${missing[@]}"
        echo -e "\n${yellow}Install talosctl:${clear}"
        echo -e "  curl -sL https://talos.dev/install | sh"
        echo -e "\n${yellow}Or via Homebrew:${clear}"
        echo -e "  brew install siderolabs/tap/talosctl"
        echo -e "\n${yellow}Install yq:${clear}"
        echo -e "  https://github.com/mikefarah/yq/#install"
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
    local custom_cni="${8:-default}"
    local memory="${9:-4096}"
    local backend="${10:-docker}"

    local cluster_dir="$clustersDir/$cluster_name"
    local talos_dir="$cluster_dir/talos"
    mkdir -p "$talos_dir"

    # Save backend choice for reference
    echo "$backend" > "$cluster_dir/backend.txt"

    # Generate Talos machine configuration files.
    # These are for reference and potential future use (e.g. adding nodes manually).
    # talosctl cluster create will generate its own configs internally.
    echo -e "${yellow}\n⏰ Generating Talos machine configuration${clear}"
    # The endpoint needs to be the address of the first controlplane, reachable from other nodes.
    # In the docker network created by talosctl, this will be the container name.
    local endpoint_host
    endpoint_host=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')-controlplane-1
    
    # Create CNI patch file if custom CNI is requested (used by both gen config and cluster create)
    local cni_patch_file=""
    if [ "$custom_cni" != "default" ]; then
        cni_patch_file="$talos_dir/cni-patch.yaml"
        cat > "$cni_patch_file" <<EOF
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
EOF
    fi
    
    # Build talosctl gen config command with optional CNI flags
    # Use --force to overwrite existing config files from previous attempts
    local gen_config_cmd="talosctl gen config \"$cluster_name\" \"https://$endpoint_host:6443\" --kubernetes-version \"$k8s_version\" --additional-sans \"127.0.0.1\" --force"
    
    # Add CNI flags if custom CNI is requested
    if [ "$custom_cni" != "default" ]; then
        gen_config_cmd="$gen_config_cmd --config-patch @$cni_patch_file"
    fi
    
    (cd "$talos_dir" && eval $gen_config_cmd >/dev/null ||
    {
        echo -e "${red} 🛑 Could not generate Talos config${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Creating Talos cluster using talosctl${clear}"
    echo -e "${yellow}   Backend: ${blue}$backend${clear}"

    # Get talosctl version to determine command structure
    local talos_version
    talos_version=$(talos_get_version)
    local talos_major_minor
    talos_major_minor=$(echo "$talos_version" | awk -F. '{print $1"."$2}')

    # Build talosctl cluster create command
    # v1.12+ uses subcommands (docker/qemu) with different flags
    # v1.11 and earlier use direct flags on cluster create
    local create_cmd=""
    local cluster_count
    cluster_count=$(talos_list_clusters | wc -l)
    local cidr_octet=$((5 + cluster_count))
    local actual_controlplane_count=$controlplane_count

    if [[ "$talos_major_minor" == "1.12" ]] || [[ "${talos_major_minor%%.*}" -gt 1 ]] || [[ "${talos_major_minor#*.}" -ge 12 && "${talos_major_minor%%.*}" -eq 1 ]]; then
        # talosctl v1.12+ command structure - uses subcommands (docker/qemu)
        
        if [ "$backend" == "qemu" ]; then
            # QEMU backend - full VM emulation, supports multiple control planes
            create_cmd="talosctl cluster create qemu"
            create_cmd="$create_cmd --name $cluster_name"
            create_cmd="$create_cmd --cidr 10.${cidr_octet}.0.0/24"
            create_cmd="$create_cmd --controlplanes $controlplane_count"
            create_cmd="$create_cmd --workers $worker_count"
            create_cmd="$create_cmd --kubernetes-version $k8s_version"
            create_cmd="$create_cmd --memory-controlplanes ${memory}MB"
            create_cmd="$create_cmd --memory-workers ${memory}MB"
            # Add CNI patch file if custom CNI is requested
            if [ "$custom_cni" != "default" ] && [ -n "$cni_patch_file" ]; then
                create_cmd="$create_cmd --config-patch @$cni_patch_file"
            fi
            # QEMU requires a preset
            create_cmd="$create_cmd --presets iso"
        else
            # Docker backend - lightweight containers
            create_cmd="talosctl cluster create docker"
            create_cmd="$create_cmd --name $cluster_name"
            create_cmd="$create_cmd --subnet 10.${cidr_octet}.0.0/24"
            
            # Docker provider doesn't support --controlplanes in v1.12+, always creates 1
            if [ "$controlplane_count" -gt 1 ]; then
                echo -e "${yellow}⚠️  Notice: talosctl cluster create with Docker backend does not support multiple control planes${clear}"
                echo -e "${yellow}   Creating cluster with 1 control plane (requested: $controlplane_count)${clear}"
                echo -e "${yellow}   💡 Tip: Use QEMU backend for multiple control planes${clear}"
                actual_controlplane_count=1
            fi
            
            create_cmd="$create_cmd --workers $worker_count"
            create_cmd="$create_cmd --kubernetes-version $k8s_version"
            # Memory flags require unit suffix (MB or GB) in v1.12+
            create_cmd="$create_cmd --memory-controlplanes ${memory}MB"
            create_cmd="$create_cmd --memory-workers ${memory}MB"
            # Expose ports for hostNetwork mode (only available in docker backend)
            create_cmd="$create_cmd --exposed-ports $http_port:80/tcp,$https_port:443/tcp"
            # Add CNI patch file if custom CNI is requested
            if [ "$custom_cni" != "default" ] && [ -n "$cni_patch_file" ]; then
                create_cmd="$create_cmd --config-patch @$cni_patch_file"
            fi
        fi
    else
        # talosctl v1.11 and earlier command structure (no subcommands)
        create_cmd="talosctl cluster create"
        create_cmd="$create_cmd --name $cluster_name"
        create_cmd="$create_cmd --cidr 10.${cidr_octet}.0.0/24"
        create_cmd="$create_cmd --controlplanes $controlplane_count"
        create_cmd="$create_cmd --workers $worker_count"
        create_cmd="$create_cmd --kubernetes-version $k8s_version"
        create_cmd="$create_cmd --memory $memory"
        create_cmd="$create_cmd --memory-workers $memory"
        # Expose ports for single control plane
        if [ "$controlplane_count" -eq 1 ]; then
            create_cmd="$create_cmd --exposed-ports $http_port:80/tcp,$https_port:443/tcp"
        fi
        # Add CNI patch file if custom CNI is requested
        if [ "$custom_cni" != "default" ] && [ -n "$cni_patch_file" ]; then
            create_cmd="$create_cmd --config-patch @$cni_patch_file"
        fi
        # Wait flags available in older versions
        if [ "$custom_cni" == "default" ]; then
            create_cmd="$create_cmd --wait --wait-timeout 5m"
        else
            create_cmd="$create_cmd --skip-k8s-node-readiness-check --wait --wait-timeout 5m"
        fi
    fi

    # Create the cluster using talosctl
    echo -e "${yellow}Running: talosctl cluster create ($backend) with $actual_controlplane_count control plane(s) and $worker_count worker(s)${clear}"

    # print the command for debugging
    echo -e "${yellow}Command: $create_cmd${clear}"

    # For v1.12+ docker backend with custom CNI, the command will hang waiting for nodes to be ready
    # (since nodes need CNI to become ready). We use a timeout and check if containers are running.
    local use_timeout=false
    if [[ "$talos_major_minor" == "1.12" ]] || [[ "${talos_major_minor%%.*}" -gt 1 ]]; then
        if [ "$backend" == "docker" ] && [ "$custom_cni" != "default" ]; then
            use_timeout=true
            echo -e "${yellow}ℹ️  Note: With custom CNI, nodes won't be Ready until CNI is installed${clear}"
            echo -e "${yellow}   The cluster creation will proceed once bootstrap is complete...${clear}"
        fi
    fi

    if [ "$use_timeout" == "true" ]; then
        # Run with timeout - cluster will be created but waiting for nodes to be ready will timeout
        # We consider it success if the controlplane container is running
        (
            # Start the command in background
            $create_cmd &
            local cmd_pid=$!
            
            # Wait for either completion or timeout (5 minutes for bootstrap)
            local timeout_seconds=300
            local elapsed=0
            while kill -0 $cmd_pid 2>/dev/null; do
                sleep 5
                elapsed=$((elapsed + 5))
                
                # Check if controlplane is running (cluster is usable)
                if docker ps --filter "name=${cluster_name}-controlplane-1" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "${cluster_name}-controlplane-1"; then
                    # Check if we can get kubeconfig (API server is up)
                    if talosctl kubeconfig /dev/null --cluster "$cluster_name" --nodes "127.0.0.1" 2>/dev/null; then
                        echo -e "${green}✅ Cluster bootstrap complete, API server is ready${clear}"
                        # Give it a few more seconds then kill the waiting process
                        sleep 10
                        kill $cmd_pid 2>/dev/null || true
                        break
                    fi
                fi
                
                if [ $elapsed -ge $timeout_seconds ]; then
                    echo -e "${yellow}⏱️  Timeout waiting for full readiness, checking cluster status...${clear}"
                    kill $cmd_pid 2>/dev/null || true
                    break
                fi
            done
            wait $cmd_pid 2>/dev/null || true
        )
        
        # Verify cluster was created successfully
        if ! docker ps --filter "name=${cluster_name}-controlplane-1" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "${cluster_name}-controlplane-1"; then
            echo -e "${red} 🛑 Could not create Talos cluster${clear}"
            return 1
        fi
    else
        ($create_cmd ||
        {
            echo -e "${red} 🛑 Could not create Talos cluster${clear}"
            return 1
        }) & spinner
    fi

    # talosctl automatically generates configs, let's move them to our talos dir
    if [ -d "$HOME/.talos/clusters/$cluster_name" ]; then
        cp "$HOME/.talos/clusters/$cluster_name/talosconfig" "$talos_dir/talosconfig" 2>/dev/null || true
    fi

    # Get kubeconfig
    echo -e "${yellow}\n⏰ Retrieving kubeconfig${clear}"
    (talos_get_kubeconfig "$cluster_name" "$cluster_dir/kubeconfig" ||
    {
        echo -e "${red} 🛑 Could not retrieve kubeconfig${clear}"
        return 1
    }) & spinner

    # Set the context
    export KUBECONFIG="$cluster_dir/kubeconfig"

    # Update context name to match our convention
    kubectl config rename-context "admin@$cluster_name" "admin@$cluster_name" 2>/dev/null || true

    # Wait for nodes to be ready (skip if custom CNI as nodes need CNI to be ready)
    if [ "$custom_cni" == "default" ]; then
        echo -e "${yellow}\n⏰ Verifying cluster nodes are ready${clear}"
        (kubectl wait --for=condition=Ready nodes --all --timeout=60s ||
        {
            echo -e "${red} 🛑 Cluster nodes not ready in time${clear}"
            return 1
        }) & spinner
    else
        echo -e "${yellow}\n⏰ Cluster created (nodes will be ready after CNI installation)${clear}"
        # Just verify API server is reachable
        kubectl get nodes >/dev/null 2>&1 || {
            echo -e "${red} 🛑 Cannot communicate with cluster API server${clear}"
            return 1
        }
    fi

    echo -e "${yellow} ✅ Talos cluster created successfully${clear}"
    return 0
}

talos_delete_cluster() {
    local cluster_name="$1"

    echo -e "${yellow}\n⏰ Deleting Talos cluster using talosctl${clear}"

    # Clean up proxy container if it exists
    local proxy_container="${cluster_name}-ingress-proxy"
    if docker ps -a --filter "name=^${proxy_container}$" --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
        echo -e "${yellow}Removing ingress proxy container${clear}"
        docker stop "$proxy_container" >/dev/null 2>&1 || true
        docker rm "$proxy_container" >/dev/null 2>&1 || true
    fi

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
    # local talos_api_port
    # talos_api_port=$(docker port "${cluster_name}-controlplane-1" 50000/tcp | awk -F: '{print $2}')

    # if [ -z "$talos_api_port" ]; then
    #     echo -e "${red} 🛑 Could not find mapped Talos API port for ${cluster_name}-controlplane-1. Kubeconfig retrieval might fail.${clear}" >&2
    #     local node_addr="127.0.0.1"
    # else
    #     local node_addr="127.0.0.1:${talos_api_port}"
    # fi

    # talosctl can export kubeconfig directly by cluster name
    talosctl kubeconfig "$output_file" \
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

    # Get the number of control planes from the cluster
    local controlplane_count
    controlplane_count=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l | tr -d ' ')

    if [ "$controlplane_count" -eq 1 ]; then
        talos_setup_ingress_single_controlplane "$cluster_name" "$http_port" "$https_port"
    else
        talos_setup_ingress_multi_controlplane "$cluster_name" "$http_port" "$https_port"
    fi
}

talos_setup_ingress_single_controlplane() {
    local cluster_name="$1"
    local http_port="$2"
    local https_port="$3"

    echo -e "${yellow}Installing Nginx Ingress Controller for Talos (single control plane, hostNetwork mode)${clear}"
    
    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml ||
    {
        echo -e "${red} 🛑 Could not install Nginx controller${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for Nginx ingress controller deployment to be available${clear}"
    (kubectl wait --namespace ingress-nginx \
        --for=condition=available deployment \
        --selector=app.kubernetes.io/component=controller \
        --timeout=180s ||
    {
        echo -e "${red} 🛑 Nginx ingress controller deployment not available in time${clear}"
        return 1
    }) & spinner

    # Label the ingress-nginx namespace
    echo -e "${yellow}\n⏰ Applying PodSecurity policy to ingress-nginx namespace${clear}"
    (kubectl label --overwrite ns ingress-nginx pod-security.kubernetes.io/enforce=privileged ||
    {
        echo -e "${red} 🛑 Could not label ingress-nginx namespace${clear}"
        return 1
    }) & spinner

    # Patch for hostNetwork
    echo -e "${yellow}\n⏰ Configuring ingress for host network access on the control plane${clear}"
    local controlplane_hostname
    controlplane_hostname=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')-controlplane-1

    local patch_payload
    patch_payload=$(printf '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet","nodeSelector":{"kubernetes.io/hostname":"%s"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}' "$controlplane_hostname")

    (kubectl patch deployment -n ingress-nginx ingress-nginx-controller -p "$patch_payload" ||
    {
        echo -e "${red} 🛑 Could not patch ingress deployment${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for Nginx ingress controller to be ready after patching${clear}"
    (kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s ||
    {
        echo -e "${red} 🛑 Nginx ingress controller rollout failed after patching${clear}"
        return 1
    }) & spinner

    echo -e "${yellow} ✅ Done installing Nginx Ingress Controller${clear}"
    return 0
}

talos_setup_ingress_multi_controlplane() {
    local cluster_name="$1"
    local http_port="$2"
    local https_port="$3"

    echo -e "${yellow}Installing MetalLB for Talos (multi control plane setup)${clear}"
    
    # Determine the CIDR octet from existing cluster
    local cluster_count
    cluster_count=$(talos_list_clusters | wc -l | tr -d ' ')
    local cidr_octet=$((5 + cluster_count - 1))
    
    # Calculate MetalLB IP address pool - 2 IPs per cluster
    # First cluster: 101-102, Second: 103-104, Third: 105-106, etc.
    local cluster_index=$((cluster_count - 1))
    local ip_start=$((101 + (cluster_index * 2)))
    local ip_end=$((ip_start + 1))
    
    local metallb_start="10.${cidr_octet}.0.${ip_start}"
    local metallb_end="10.${cidr_octet}.0.${ip_end}"
    
    echo -e "${yellow}Using MetalLB IP range: ${metallb_start}-${metallb_end}${clear}"

    # Create metallb-system namespace with PodSecurity labels
    echo -e "${yellow}\n⏰ Creating metallb-system namespace with PodSecurity labels${clear}"
    cat <<EOF | kubectl apply -f - || { echo -e "${red} 🛑 Could not create metallb-system namespace${clear}"; return 1; }
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF

    # Install MetalLB using Helm
    echo -e "${yellow}\n⏰ Installing MetalLB using Helm${clear}"
    (helm repo add metallb https://metallb.github.io/metallb 2>/dev/null || true) & spinner
    (helm repo update metallb ||
    {
        echo -e "${red} 🛑 Could not update MetalLB Helm repo${clear}"
        return 1
    }) & spinner

    (helm install metallb metallb/metallb --namespace metallb-system --wait --timeout 180s ||
    {
        echo -e "${red} 🛑 Could not install MetalLB with Helm${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for MetalLB controller to be ready${clear}"
    (kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=metallb \
        --timeout=180s ||
    {
        echo -e "${red} 🛑 MetalLB pods not ready in time${clear}"
        return 1
    }) & spinner

    # Create IPAddressPool and L2Advertisement
    echo -e "${yellow}\n⏰ Configuring MetalLB IP address pool${clear}"
    
    cat <<EOF | kubectl apply -f - || { echo -e "${red} 🛑 Could not configure MetalLB${clear}"; return 1; }
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${metallb_start}-${metallb_end}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

    # Install Nginx Ingress Controller with LoadBalancer service type
    echo -e "${yellow}\n⏰ Installing Nginx Ingress Controller${clear}"
    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml ||
    {
        echo -e "${red} 🛑 Could not install Nginx controller${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for Nginx ingress controller to be ready${clear}"
    (kubectl wait --namespace ingress-nginx \
        --for=condition=available deployment \
        --selector=app.kubernetes.io/component=controller \
        --timeout=180s ||
    {
        echo -e "${red} 🛑 Nginx ingress controller deployment not available in time${clear}"
        return 1
    }) & spinner

    # Wait for LoadBalancer IP to be assigned
    echo -e "${yellow}\n⏰ Waiting for LoadBalancer IP assignment${clear}"
    local retries=30
    local lb_ip=""
    while [ $retries -gt 0 ]; do
        lb_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$lb_ip" ]; then
            echo -e "${yellow} ✅ LoadBalancer IP assigned: ${blue}${lb_ip}${clear}"
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done

    if [ -z "$lb_ip" ]; then
        echo -e "${red} 🛑 LoadBalancer IP not assigned in time${clear}"
        return 1
    fi

    # Set up proxy container for routing traffic from host to MetalLB IP
    echo -e "${yellow}\n⏰ Setting up proxy container for ingress routing${clear}"
    
    local proxy_container="${cluster_name}-ingress-proxy"
    
    # Get the Docker network name from the control plane container
    local network_name=$(docker inspect "${cluster_name}-controlplane-1" --format='{{range $net,$v := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null | head -1)
    
    if [ -z "$network_name" ]; then
        echo -e "${red} 🛑 Could not find Docker network for cluster${clear}"
        return 1
    fi
    
    echo -e "${yellow}Using Docker network: ${blue}${network_name}${clear}"
    
    # Stop and remove proxy container if it exists
    docker stop "$proxy_container" >/dev/null 2>&1 || true
    docker rm "$proxy_container" >/dev/null 2>&1 || true
    
    # Start proxy container
    # This container runs HAProxy to forward traffic from host ports to MetalLB IP
    echo -e "${yellow}Creating proxy container: ${blue}${proxy_container}${clear}"
    
    # Create HAProxy config in /tmp (writable location)
    local haproxy_config="
global
    log stdout format raw local0
    maxconn 4096

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http_front
    bind :80
    default_backend http_back

frontend https_front
    bind :443
    default_backend https_back

backend http_back
    server metallb ${lb_ip}:80 check

backend https_back
    server metallb ${lb_ip}:443 check
"
    
    docker run -d \
        --name "$proxy_container" \
        --network "$network_name" \
        --restart unless-stopped \
        -p "${http_port}:80" \
        -p "${https_port}:443" \
        haproxy:alpine \
        sh -c "echo '$haproxy_config' > /tmp/haproxy.cfg && haproxy -f /tmp/haproxy.cfg" \
        >/dev/null 2>&1 || {
        echo -e "${red} 🛑 Could not create proxy container${clear}"
        docker logs "$proxy_container" 2>&1 | tail -10
        return 1
    }
    
    # Wait for proxy to be ready
    sleep 3
    
    # Verify proxy container is running
    if ! docker ps --filter "name=^${proxy_container}$" --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
        echo -e "${red} 🛑 Proxy container failed to start${clear}"
        echo -e "${yellow}Container logs:${clear}"
        docker logs "$proxy_container" 2>&1
        return 1
    fi

    echo -e "${yellow} ✅ Done installing Nginx Ingress Controller with MetalLB${clear}"
    echo -e "${yellow} ✅ Traffic flow: localhost:${http_port}/${https_port} → Proxy Container → MetalLB ${lb_ip} → Ingress${clear}"
    echo -e "${yellow} ℹ️  Proxy container: ${blue}${proxy_container}${clear} (auto-restarts)${clear}"
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