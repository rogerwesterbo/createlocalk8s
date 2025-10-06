#!/bin/bash

# Provider Interface Contract
# All providers must implement these functions to be compatible with k8s-local

# Provider Interface Documentation:
# Each provider implementation must define these functions:
#
# REQUIRED FUNCTIONS:
# -------------------
# provider_check_prerequisites()
#   - Verify all required CLI tools are installed for this provider
#   - Exit with error if prerequisites are missing
#   - Return: 0 on success
#
# provider_create_cluster(cluster_name, config_file, k8s_version, controlplane_count, worker_count, http_port, https_port)
#   - Create a new Kubernetes cluster with the given specifications
#   - Args:
#     - cluster_name: Name of the cluster to create
#     - config_file: Path to provider-specific config file
#     - k8s_version: Kubernetes version to use
#     - controlplane_count: Number of control plane nodes
#     - worker_count: Number of worker nodes
#     - http_port: HTTP port for ingress
#     - https_port: HTTPS port for ingress
#   - Return: 0 on success, 1 on failure
#
# provider_delete_cluster(cluster_name)
#   - Delete an existing cluster
#   - Args:
#     - cluster_name: Name of the cluster to delete
#   - Return: 0 on success, 1 on failure
#
# provider_list_clusters()
#   - List all clusters managed by this provider
#   - Output: One cluster name per line
#   - Return: 0 on success
#
# provider_validate_cluster_exists(cluster_name)
#   - Check if a cluster exists
#   - Exit with error message if cluster doesn't exist
#   - Args:
#     - cluster_name: Name of cluster to check
#   - Return: 0 if exists
#
# provider_validate_cluster_not_exists(cluster_name)
#   - Check if a cluster does NOT exist
#   - Exit with error message if cluster already exists
#   - Args:
#     - cluster_name: Name of cluster to check
#   - Return: 0 if doesn't exist
#
# provider_get_kubeconfig(cluster_name, output_file)
#   - Export kubeconfig for the cluster to a file
#   - Args:
#     - cluster_name: Name of the cluster
#     - output_file: Path where kubeconfig should be written
#   - Return: 0 on success, 1 on failure
#
# provider_get_cluster_context(cluster_name)
#   - Get the kubectl context name for this cluster
#   - Args:
#     - cluster_name: Name of the cluster
#   - Output: Context name (e.g., "kind-mycluster" or "admin@mycluster")
#   - Return: 0 on success
#
# provider_setup_ingress(cluster_name, http_port, https_port)
#   - Setup ingress controller for the cluster
#   - Provider-specific implementation (e.g., kind needs special patches)
#   - Args:
#     - cluster_name: Name of the cluster
#     - http_port: HTTP port for ingress
#     - https_port: HTTPS port for ingress
#   - Return: 0 on success, 1 on failure
#
# provider_get_info()
#   - Return provider-specific information as key-value pairs
#   - Output: Multi-line format "Key: Value"
#   - Return: 0 on success
#
# provider_supports_multi_cluster()
#   - Indicate if provider supports running multiple clusters simultaneously
#   - Output: "yes" or "no"
#   - Return: 0 on success

# Helper function to check if a provider is loaded
provider_is_loaded() {
    local provider_name="$1"
    declare -f "${provider_name}_create_cluster" >/dev/null 2>&1
}

# Load a provider by name
load_provider() {
    local provider_name="$1"
    local provider_file="$SCRIPT_DIR/scripts/providers/${provider_name}-provider.sh"

    if [ ! -f "$provider_file" ]; then
        echo -e "${red}Provider '$provider_name' not found at: $provider_file${clear}"
        return 1
    fi

    source "$provider_file"

    if ! provider_is_loaded "$provider_name"; then
        echo -e "${red}Provider '$provider_name' did not load correctly${clear}"
        return 1
    fi

    return 0
}

# Get the provider for a cluster
get_cluster_provider() {
    local cluster_name="$1"
    local provider_file="$clustersDir/$cluster_name-provider.txt"

    if [ -f "$provider_file" ]; then
        cat "$provider_file"
    else
        # Default to kind for backward compatibility
        echo "kind"
    fi
}

# Set the provider for a cluster
set_cluster_provider() {
    local cluster_name="$1"
    local provider_name="$2"
    echo "$provider_name" > "$clustersDir/$cluster_name-provider.txt"
}

# Validate that all required provider functions are implemented
validate_provider() {
    local provider_name="$1"
    local required_functions=(
        "check_prerequisites"
        "create_cluster"
        "delete_cluster"
        "list_clusters"
        "validate_cluster_exists"
        "validate_cluster_not_exists"
        "get_kubeconfig"
        "get_cluster_context"
        "setup_ingress"
        "get_info"
        "supports_multi_cluster"
    )

    local missing_functions=()

    for func in "${required_functions[@]}"; do
        if ! declare -f "${provider_name}_${func}" >/dev/null 2>&1; then
            missing_functions+=("${provider_name}_${func}")
        fi
    done

    if [ ${#missing_functions[@]} -gt 0 ]; then
        echo -e "${red}Provider '$provider_name' is missing required functions:${clear}"
        printf '%s\n' "${missing_functions[@]}"
        return 1
    fi

    return 0
}

# Call a provider function
call_provider_function() {
    local provider_name="$1"
    local function_name="$2"
    shift 2

    local full_function="${provider_name}_${function_name}"

    if ! declare -f "$full_function" >/dev/null 2>&1; then
        echo -e "${red}Provider function '$full_function' not found${clear}"
        return 1
    fi

    "$full_function" "$@"
}
