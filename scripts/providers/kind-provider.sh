#!/bin/bash

# Kind Provider Implementation
# Implements the provider interface for kind (Kubernetes in Docker)

kind_check_prerequisites() {
    local missing=()

    if ! command -v kind &> /dev/null; then
        missing+=("kind")
    fi

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${red}Missing prerequisites for kind provider:${clear}"
        printf '%s\n' "${missing[@]}"
        echo -e "\n${yellow}Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/${clear}"
        return 1
    fi

    return 0
}

kind_create_cluster() {
    local cluster_name="$1"
    local config_file="$2"
    local k8s_version="$3"
    local controlplane_count="$4"
    local worker_count="$5"
    local http_port="$6"
    local https_port="$7"
    local custom_cni="${8:-default}"

    echo -e "${yellow}\n⏰ Creating Kind cluster${clear}"

    (kind create cluster --name "$cluster_name" --config "$config_file" ||
    {
        echo -e "${red} 🛑 Could not create cluster ...${clear}"
        return 1
    }) & spinner

    # Ensure kubectl is using the correct context
    echo -e "${yellow}\n🔄 Switching to cluster context: kind-$cluster_name${clear}"
    kubectl config use-context "kind-$cluster_name" 2>/dev/null || {
        echo -e "${red} 🛑 Could not switch to cluster context${clear}"
        return 1
    }

    # Verify cluster is ready (skip if custom CNI as nodes need CNI to be ready)
    if [ "$custom_cni" == "default" ]; then
        echo -e "${yellow}\n⏰ Waiting for cluster nodes to be ready...${clear}"
        kubectl wait --for=condition=Ready nodes --all --timeout=60s || {
            echo -e "${red} 🛑 Cluster nodes not ready in time${clear}"
            return 1
        }
    else
        echo -e "${yellow}\n⏰ Cluster created (nodes will be ready after CNI installation)${clear}"
        # Just verify API server is reachable
        kubectl get nodes >/dev/null 2>&1 || {
            echo -e "${red} 🛑 Cannot communicate with cluster API server${clear}"
            return 1
        }
    fi

    return 0
}

kind_delete_cluster() {
    local cluster_name="$1"

    (kind delete cluster --name "$cluster_name" ||
    {
        echo -e "${red} 🛑 Could not delete cluster with name $cluster_name${clear}"
        return 1
    }) & spinner

    return 0
}

kind_list_clusters() {
    kind get clusters 2>/dev/null
}

kind_validate_cluster_exists() {
    local cluster_name="$1"

    if [ -z "$cluster_name" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty${clear}"
        exit 1
    fi

    local clusters
    clusters=$(kind get clusters 2>/dev/null)

    if ! echo "$clusters" | grep -q "^${cluster_name}$"; then
        echo -e "${red}\n🛑 Cluster '${cluster_name}' not found${clear}"
        echo -e "${yellow}\nAvailable clusters:${clear}"
        kind get clusters
        exit 1
    fi
}

kind_validate_cluster_not_exists() {
    local cluster_name="$1"

    if [ -z "$cluster_name" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty${clear}"
        exit 1
    fi

    local clusters
    clusters=$(kind get clusters 2>/dev/null)

    if echo "$clusters" | grep -q "^${cluster_name}$"; then
        echo -e "${red}\n🛑 Cluster '${cluster_name}' already exists${clear}"
        echo -e "${yellow}\nPlease choose a different name or delete the existing cluster first:${clear}"
        echo -e "  ${blue}./kl.sh delete ${cluster_name}${clear}"
        exit 1
    fi
}

kind_get_kubeconfig() {
    local cluster_name="$1"
    local output_file="$2"

    kind get kubeconfig --name "$cluster_name" > "$output_file" 2>/dev/null
    return $?
}

kind_get_cluster_context() {
    local cluster_name="$1"
    echo "kind-$cluster_name"
}

kind_setup_ingress() {
    local cluster_name="$1"
    local http_port="$2"
    local https_port="$3"

    echo -e "${yellow}Creating Nginx Ingress Controller for kind${clear}"
    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml ||
    {
        echo -e "${red} 🛑 Could not install Nginx controller in cluster ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Patching Nginx controller to run on control-plane node${clear}"
    (kubectl patch deployment -n ingress-nginx ingress-nginx-controller -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"}}}}}' ||
    {
        echo -e "${red} 🛑 Could not patch Nginx controller ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow}\n⏰ Waiting for Nginx ingress controller for kind to be ready${clear}"
    sleep 10
    (kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s ||
    {
        echo -e "${red} 🛑 Could not install Nginx ingress controller into cluster ...${clear}"
        return 1
    }) & spinner

    echo -e "${yellow} ✅ Done installing Nginx Ingress Controller${clear}"
    return 0
}

kind_get_info() {
    echo "Provider: kind"
    echo "Provider URL: https://kind.sigs.k8s.io/"
    echo "Container Runtime: Docker"
}

kind_supports_multi_cluster() {
    echo "yes"
}

# Kind-specific helper: Generate kind config file
kind_generate_config() {
    local cluster_name="$1"
    local config_file="$2"
    local k8s_image="$3"
    local controlplane_count="$4"
    local worker_count="$5"
    local http_port="$6"
    local https_port="$7"
    local custom_cni="${8:-default}"

    # Clear or create config file
    if [ -e "$config_file" ] && [ -r "$config_file" ] && [ -w "$config_file" ]; then
        truncate -s 0 "$config_file"
    fi

    if [ ! -f "$config_file" ]; then
        touch "$config_file"
    fi

    # Write header
    echo "kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual" >> "$config_file"

    # Add disableDefaultCNI if custom CNI is requested
    if [ "$custom_cni" != "default" ]; then
        echo "  disableDefaultCNI: true" >> "$config_file"
    fi

    echo "nodes:" >> "$config_file"

    # Add control plane nodes
    for i in $(seq 1 "$controlplane_count"); do
        # Only the first control plane gets port mappings
        if [ "$i" -eq 1 ]; then
            echo "  - role: control-plane
    image: $k8s_image
    labels:
        ingress-ready: \"true\"
    extraPortMappings:
      - containerPort: 80
        hostPort: $http_port
        protocol: TCP
      - containerPort: 443
        hostPort: $https_port
        protocol: TCP" >> "$config_file"
        else
            # Additional control planes don't get host port mappings
            echo "  - role: control-plane
    image: $k8s_image" >> "$config_file"
        fi
    done

    # Add worker nodes
    if [ "$worker_count" -gt 0 ]; then
        for i in $(seq 1 "$worker_count"); do
            echo "  - role: worker
    image: $k8s_image" >> "$config_file"
        done
    fi
}

# Kind-specific helper: Check if running multiple clusters
kind_is_running_multiple_clusters() {
    local clusters
    clusters=$(kind get clusters -q 2>/dev/null)

    if [ "$clusters" == "No kind clusters found." ] || [ -z "$clusters" ]; then
        echo "no"
    elif [[ $(echo "$clusters" | wc -l) -ge 2 ]]; then
        echo "yes"
    else
        echo "no"
    fi
}
